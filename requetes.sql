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

SELECT L.id_logement,
       L.emplacement,
       COUNT(I.id_intervention) AS nb_interventions
FROM Logement L
LEFT JOIN Logement_Intervention LI ON L.id_logement = LI.id_logement
LEFT JOIN Intervention I ON LI.id_intervention = I.id_intervention
GROUP BY L.id_logement, L.emplacement
ORDER BY nb_interventions DESC;
--Liste des logements disponibles pour une période spécifique
SELECT L.id_logement, L.emplacement, L.loyer, T.type_logement
FROM Logement L
JOIN Type_logement T ON L.id_type_logement = T.id_type_logement
WHERE NOT EXISTS (
    SELECT 1 FROM Reservation R
    WHERE R.id_logement = L.id_logement
    AND ('2025-03-01' BETWEEN R.date_debut AND R.date_fin
         OR '2025-03-15' BETWEEN R.date_debut AND R.date_fin
         OR (R.date_debut BETWEEN '2025-03-01' AND '2025-03-15')
         OR (R.date_fin BETWEEN '2025-03-01' AND '2025-03-15'))
)
AND T.type_logement = 'Studio'
AND L.emplacement = 'Centre-ville'
AND L.loyer <= 1000;

--Liste des résidents ayant prolongé leur séjour :

SELECT R.nom,
       R.prenom,
       MAX(Res2.date_fin) AS date_sortie_prolongée
FROM Resident R
JOIN Reservation Res1 ON R.id_resident = Res1.id_resident
JOIN Reservation Res2 ON R.id_resident = Res2.id_resident
    AND Res1.id_logement = Res2.id_logement  
    AND Res1.date_fin = Res2.date_debut      
GROUP BY R.nom, R.prenom
HAVING MAX(Res2.date_fin) > CURRENT_DATE;

--Liste des logements avec le nombre de demandes en attente 

SELECT L.id_logement, 
       L.emplacement,
       COUNT(R.id_reservation) AS nb_demandes_attente
FROM Logement L
LEFT JOIN Reservation R ON L.id_logement = R.id_logement
WHERE R.date_fin >= CURRENT_DATE
GROUP BY L.id_logement, L.emplacement
ORDER BY nb_demandes_attente DESC;

--Liste des logements avec le nombre d'interventions et la moyenne des notes :

SELECT 
    L.id_logement, 
    L.emplacement, 
    COALESCE(COUNT(I.id_intervention), 0) AS nb_ameliorations, 
    COALESCE(ROUND(AVG(N.score), 2), 0) AS moyenne_notes
FROM Logement L
LEFT JOIN Logement_Intervention LI ON L.id_logement = LI.id_logement
LEFT JOIN Intervention I ON LI.id_intervention = I.id_intervention
LEFT JOIN Note N ON L.id_logement = N.id_logement
WHERE I.id_type_intervention IN (2, 3)
GROUP BY L.id_logement, L.emplacement
ORDER BY moyenne_notes DESC;

--Liste des logements avec le nombre de résidents actifs :


SELECT L.id_logement, L.emplacement, COUNT(DISTINCT R.id_resident) AS nb_residents
FROM Logement L
JOIN Reservation Res ON L.id_logement = Res.id_logement
JOIN Resident R ON Res.id_resident = R.id_resident
WHERE CURRENT_DATE BETWEEN Res.date_debut AND Res.date_fin
GROUP BY L.id_logement, L.emplacement;


--trigger pour mettre à jour le statut du logement après une intervention :

DROP TRIGGER IF EXISTS trigger_update_logement_status ON Logement_Intervention;
DROP FUNCTION IF EXISTS update_logement_status();

CREATE FUNCTION update_logement_status()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE Logement
    SET etat = 'En maintenance'
    WHERE id_logement = NEW.id_logement;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_update_logement_status
AFTER INSERT ON Logement_Intervention
FOR EACH ROW
EXECUTE FUNCTION update_logement_status();
--Création de fonction et trigger pour libérer le logement après une annulation de réservation :

DROP TRIGGER IF EXISTS trigger_liberer_logement ON Reservation;
DROP FUNCTION IF EXISTS liberer_logement();

CREATE FUNCTION liberer_logement()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE Logement
    SET etat = 'Disponible'
    WHERE id_logement = OLD.id_logement;
    RETURN OLD;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_liberer_logement
AFTER DELETE ON Reservation
FOR EACH ROW
EXECUTE FUNCTION liberer_logement();

--Profil démographique des résidents :

SELECT 
    r.nom, 
    r.prenom, 
    EXTRACT(YEAR FROM AGE(r.date_naissance)) AS age,
    p.profession, 
    p.secteur_activite, 
    r.date_entree, 
    r.date_sortie
FROM 
    Resident r
JOIN 
    Profil p ON r.id_profil = p.id_profil;



