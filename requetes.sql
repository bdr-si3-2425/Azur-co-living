-- A. Quels logements sont disponibles pour une période donnée, selon des critères spécifiques (type, emplacement, prix) ?
CREATE OR REPLACE FUNCTION logements_disponibles(
    p_type_logement VARCHAR, 
    p_emplacement VARCHAR, 
    p_prix_min FLOAT, 
    p_prix_max FLOAT, 
    p_date_debut DATE, 
    p_date_fin DATE
) RETURNS TABLE(id_logement INT, emplacement VARCHAR, surface FLOAT, loyer FLOAT, nombre_chambres INT, type_logement VARCHAR) AS $$
BEGIN
    RETURN QUERY 
    SELECT l.id_logement, l.emplacement, l.surface, l.loyer, l.nombre_chambres, tl.type_logement
    FROM Logement l
    JOIN Type_logement tl ON l.id_type_logement = tl.id_type_logement
    WHERE tl.type_logement = p_type_logement
      AND l.emplacement = p_emplacement
      AND l.loyer BETWEEN p_prix_min AND p_prix_max
      AND NOT EXISTS (
          SELECT 1
          FROM Reservation r
          WHERE r.id_logement = l.id_logement
            AND ((r.date_debut BETWEEN p_date_debut AND p_date_fin) OR (r.date_fin BETWEEN p_date_debut AND p_date_fin))
      );
END;
$$ LANGUAGE plpgsql;





-- B. Comment gérer les réservations et attribuer les logements aux nouveaux résidents en optimisant l’occupation ?

CREATE OR REPLACE FUNCTION attribuer_logement_optimise(
    p_id_resident INT, 
    p_date_debut DATE, 
    p_date_fin DATE
) RETURNS VOID AS $$
DECLARE
    v_logement_id INT;
BEGIN
    -- Recherche d'un logement disponible pour la période donnée
    SELECT l.id_logement
    INTO v_logement_id
    FROM Logement l
    WHERE NOT EXISTS (
        SELECT 1
        FROM Reservation r
        WHERE r.id_logement = l.id_logement
          AND ((r.date_debut BETWEEN p_date_debut AND p_date_fin) OR (r.date_fin BETWEEN p_date_debut AND p_date_fin))
    )
    LIMIT 1;
    
    -- Si un logement est trouvé, créer la réservation
    IF v_logement_id IS NOT NULL THEN
        INSERT INTO Reservation (date_debut, date_fin, id_logement, id_resident)
        VALUES (p_date_debut, p_date_fin, v_logement_id, p_id_resident);
    ELSE
        RAISE EXCEPTION 'Aucun logement disponible pour cette période';
    END IF;
END;
$$ LANGUAGE plpgsql;





-- 1. Quel est le taux d'occupation actuel des logements ?
SELECT 
    (COUNT(DISTINCT r.id_logement)::FLOAT / COUNT(l.id_logement)) * 100 AS taux_occupation
FROM 
    Logement l
LEFT JOIN 
    Reservation r ON r.id_logement = l.id_logement
    AND r.date_fin >= CURRENT_DATE;






-- 6. Quel est le temps moyen de séjour d'un résident dans un logement ?
SELECT 
    AVG(DATE_PART('day', r.date_fin - r.date_debut)) AS temps_moyen_sejour
FROM 
    Reservation r;



-- 13. Quel est le profil des résidents qui prolongent leur séjour par rapport à ceux qui ne prolongent pas ?

SELECT 
    p.profession, 
    p.secteur_activite, 
    COUNT(r.id_resident) AS nombre_residents
FROM 
    Resident r
JOIN 
    Profil p ON r.id_profil = p.id_profil
JOIN 
    Reservation res ON r.id_resident = res.id_resident
WHERE 
    res.date_sortie IS NULL OR res.date_sortie > res.date_fin
GROUP BY 
    p.profession, p.secteur_activite;




-- 16. Quelles sont les tendances de réservation sur différentes périodes (mois, trimestre, année) ?
-- Pour le mois
SELECT 
    DATE_TRUNC('month', r.date_debut) AS periode, 
    COUNT(*) AS nombre_reservations
FROM 
    Reservation r
GROUP BY 
    DATE_TRUNC('month', r.date_debut);

-- Pour le trimestre
SELECT 
    DATE_TRUNC('quarter', r.date_debut) AS periode, 
    COUNT(*) AS nombre_reservations
FROM 
    Reservation r
GROUP BY 
    DATE_TRUNC('quarter', r.date_debut);

-- Pour l'année
SELECT 
    DATE_TRUNC('year', r.date_debut) AS periode, 
    COUNT(*) AS nombre_reservations
FROM 
    Reservation r
GROUP BY 
    DATE_TRUNC('year', r.date_debut);



-- 18. Combien de résidents sont inscrits dans des activités régulières (cours, événements, etc.) ?
SELECT 
    COUNT(DISTINCT r.id_resident) AS nombre_residents
FROM 
    Resident r
JOIN 
    Participation p ON r.id_resident = p.id_resident;




-- 21. Comment les saisons affectent-elles la demande des logements ?
SELECT 
    CASE
        WHEN EXTRACT(MONTH FROM r.date_debut) IN (12, 1, 2) THEN 'Hiver'
        WHEN EXTRACT(MONTH FROM r.date_debut) IN (3, 4, 5) THEN 'Printemps'
        WHEN EXTRACT(MONTH FROM r.date_debut) IN (6, 7, 8) THEN 'Été'
        ELSE 'Automne'
    END AS saison, 
    COUNT(*) AS nombre_reservations
FROM 
    Reservation r
GROUP BY 
    saison;


