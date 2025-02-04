-- A. Quels logements sont disponibles pour une période donnée, selon des critères spécifiques (type, emplacement, prix) ?
--procedure stockée
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

--requete sql
SELECT * FROM logements_disponibles(
    'Appartement',     -- Type de logement recherché
    'Paris',           -- Emplacement recherché
    500,               -- Prix minimum
    1500,              -- Prix maximum
    '2025-02-10',      -- Date de début recherchée
    '2025-02-20'       -- Date de fin recherchée
);



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
    
  -- 7. Quels logements ont le meilleur rapport qualité/prix en fonction des avis des résidents ?
  
    SELECT 
    l.id_logement,
    l.emplacement,
    l.loyer,
    COALESCE(ROUND(AVG(n.score),2), 0) AS note_moyenne,
    CASE 
        WHEN l.loyer > 0 THEN COALESCE(ROUND(AVG(n.score),4), 0) / l.loyer
        ELSE NULL
    END AS rapport_qualite_prix
FROM Logement l
LEFT JOIN Note n ON l.id_logement = n.id_logement
GROUP BY l.id_logement, l.emplacement, l.loyer
ORDER BY rapport_qualite_prix DESC NULLS LAST;

-- 10. Quel est le taux de satisfaction des résidents en ce qui concerne les logements, les services et les événements 

SELECT 
    (SELECT ROUND(AVG(n.score), 2) FROM Note n) AS taux_satisfaction_logements,
    (SELECT ROUND(COUNT(DISTINCT p.id_resident) * 100.0 / (SELECT COUNT(*) FROM Resident))FROM Participation p) AS taux_participation_evenements;
    
-- 11. Combien de logements sont disponibles à la location dans un quartier ou une zone géographique donnée ?

SELECT emplacement, COUNT(*) AS logements_disponibles
FROM Logement
WHERE id_logement NOT IN (
    SELECT DISTINCT id_logement
    FROM Reservation
    WHERE CURRENT_DATE BETWEEN date_debut AND date_fin
)
GROUP BY emplacement;

-- 14. Quels sont les types de logements les plus rentables ?

WITH revenus AS (
    SELECT 
        tl.type_logement,
        SUM((r.date_fin - r.date_debut) * l.loyer) AS revenu_total
    FROM Reservation r
    JOIN Logement l ON r.id_logement = l.id_logement
    JOIN Type_logement tl ON l.id_type_logement = tl.id_type_logement
    GROUP BY tl.type_logement
),
interventions AS (
    SELECT 
        tl.type_logement,
        COUNT(i.id_intervention) AS nombre_interventions
    FROM logement_intervention i
    JOIN Logement l ON i.id_logement = l.id_logement
    JOIN Type_logement tl ON l.id_type_logement = tl.id_type_logement
    GROUP BY tl.type_logement
)
SELECT 
    r.type_logement,
    r.revenu_total,
    COALESCE(i.nombre_interventions, 0) AS nombre_interventions,
    (r.revenu_total - (i.nombre_interventions * 500)) AS rentabilite_estimee
FROM revenus r
LEFT JOIN interventions i ON r.type_logement = i.type_logement
ORDER BY rentabilite_estimee DESC;

-- 4. Quels résidents ont eu des comportements problématiques ou signalés des conflits récurrents ?

SELECT r.nom, r.prenom, COUNT(c.id_conflit) AS nombre_conflits
FROM Resident r
JOIN Resident_conflicts rc ON r.id_resident = rc.id_resident
JOIN Conflit c ON rc.id_conflit = c.id_conflit
WHERE c.resolu != 'oui'  
GROUP BY r.id_resident
HAVING COUNT(c.id_conflit) > 1  
ORDER BY nombre_conflits DESC;

-- F. Comment organiser les événements communautaires pour maximiser la participation des résidents dans un logement donné ?

SELECT
    Round((COUNT(DISTINCT re.id_resident) * 100.0 / (SELECT COUNT(*) FROM Resident)),2) AS taux_participation,
    e.type_evenement,
    COUNT(re.id_resident) AS nombre_participants,
    
    e.date_event
FROM Evenement e
JOIN participation re ON e.id_evenement = re.id_evenement
WHERE e.date_event BETWEEN '2024-01-01' AND '2025-12-31'  -- Période à ajuster selon vos besoins
GROUP BY e.type_evenement, e.id_evenement, e.date_event
ORDER BY nombre_participants DESC;


