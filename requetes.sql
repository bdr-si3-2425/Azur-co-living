-- Quels logements sont disponibles pour une période donnée, selon des critères spécifiques (type, emplacement, prix) ?
-- Pocedure stockée
CREATE OR REPLACE FUNCTION logements_disponibles(
    p_date_debut DATE, 
    p_date_fin DATE, 
    p_type VARCHAR DEFAULT NULL, 
    p_emplacement VARCHAR DEFAULT NULL, 
    p_prix_max DECIMAL DEFAULT NULL
) 
RETURNS TABLE(id_logement INT, type VARCHAR, emplacement VARCHAR, prix DECIMAL) AS $$  
BEGIN  
    RETURN QUERY  
    SELECT l.id_logement, l.type, l.emplacement, l.prix
    FROM Logement l  
    WHERE NOT EXISTS (
        SELECT 1 FROM Reservation r  
        WHERE r.id_logement = l.id_logement  
        AND r.date_debut <= p_date_fin  
        AND r.date_fin >= p_date_debut  
    )
    AND (p_type IS NULL OR l.type = p_type)  
    AND (p_emplacement IS NULL OR l.emplacement = p_emplacement)  
    AND (p_prix_max IS NULL OR l.prix <= p_prix_max);  
END;  
$$ LANGUAGE plpgsql;


--requete sql
SELECT * FROM logements_disponibles('2024-05-01', '2024-05-15', 'Appartement', 'Centre-ville', 1000);





-- B. Comment gérer les réservations et attribuer les logements aux nouveaux résidents en optimisant l’occupation ?
--procedure stockee
CREATE OR REPLACE FUNCTION attribuer_logement(
    p_id_resident INT, 
    p_date_debut DATE, 
    p_date_fin DATE
) 
RETURNS TABLE(id_reservation INT, id_logement INT, message TEXT) AS $$  
DECLARE  
    v_id_logement INT;  
BEGIN  
    -- Rechercher un logement libre
    SELECT l.id_logement INTO v_id_logement  
    FROM Logement l  
    WHERE NOT EXISTS (
        SELECT 1 FROM Reservation r  
        WHERE r.id_logement = l.id_logement  
        AND r.date_debut <= p_date_fin  
        AND r.date_fin >= p_date_debut  
    )  
    ORDER BY l.prix ASC  
    LIMIT 1;  

    -- Vérifier si un logement a été trouvé
    IF v_id_logement IS NULL THEN  
        RETURN QUERY SELECT NULL, NULL, 'Aucun logement disponible pour ces dates.';
    ELSE  
        -- Insérer la réservation
        INSERT INTO Reservation (id_resident, id_logement, date_debut, date_fin)  
        VALUES (p_id_resident, v_id_logement, p_date_debut, p_date_fin)  
        RETURNING id_reservation, id_logement, 'Réservation effectuée avec succès.';  
    END IF;  
END;  
$$ LANGUAGE plpgsql;

--requete
SELECT * FROM attribuer_logement(5, '2024-05-01', '2024-05-15');

-- optimisation de l'occupation pour identifier les logements sous-utilises
SELECT 
    l.id_logement, 
    l.type, 
    l.emplacement, 
    (SUM(r.date_fin - r.date_debut + 1) * 100.0) / 365 AS taux_utilisation
FROM Logement l
LEFT JOIN Reservation r ON l.id_logement = r.id_logement
WHERE EXTRACT(YEAR FROM r.date_debut) = 2024
GROUP BY l.id_logement, l.type, l.emplacement
ORDER BY taux_utilisation ASC;







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
    COUNT(r1.id_resident) AS nb_prolongations
FROM Resident r
JOIN Profil p ON r.id_profil = p.id_profil
JOIN Reservation r1 ON r.id_resident = r1.id_resident
JOIN Reservation r2 ON r1.id_resident = r2.id_resident AND r1.date_fin = r2.date_debut
GROUP BY p.profession, p.secteur_activite
ORDER BY nb_prolongations DESC;





-- 16. Quelles sont les tendances de réservation sur différentes périodes (mois, trimestre, année) ?
SELECT 
    DATE_TRUNC('month', date_debut) AS mois,
    COUNT(*) AS nombre_reservations
FROM Reservation
GROUP BY mois
ORDER BY mois;

-- autre tendance par trimestre et par anne
SELECT 
    DATE_TRUNC('quarter', date_debut) AS trimestre,
    COUNT(*) AS nombre_reservations
FROM Reservation
GROUP BY trimestre
ORDER BY trimestre;

SELECT 
    DATE_TRUNC('year', date_debut) AS annee,
    COUNT(*) AS nombre_reservations
FROM Reservation
GROUP BY annee
ORDER BY annee;





-- 18. Combien de résidents sont inscrits dans des activités régulières (cours, événements, etc.) ?
SELECT COUNT(DISTINCT id_resident) AS nb_residents_actifs 
FROM Participation;





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

SELECT L.id_logement,
       L.emplacement,
       COUNT(I.id_intervention) AS nb_interventions
FROM Logement L
LEFT JOIN Logement_Intervention LI ON L.id_logement = LI.id_logement
LEFT JOIN Intervention I ON LI.id_intervention = I.id_intervention
GROUP BY L.id_logement, L.emplacement
ORDER BY nb_interventions DESC;

-- Liste des logements disponibles pour une période spécifique
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

-- Liste des résidents ayant prolongé leur séjour :

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

-- Liste des logements avec le nombre de demandes en attente 

SELECT L.id_logement, 
       L.emplacement,
       COUNT(R.id_reservation) AS nb_demandes_attente
FROM Logement L
LEFT JOIN Reservation R ON L.id_logement = R.id_logement
WHERE R.date_fin >= CURRENT_DATE
GROUP BY L.id_logement, L.emplacement
ORDER BY nb_demandes_attente DESC;

-- Liste des logements avec le nombre d'interventions et la moyenne des notes :

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

-- Liste des logements avec le nombre de résidents actifs :


SELECT L.id_logement, L.emplacement, COUNT(DISTINCT R.id_resident) AS nb_residents
FROM Logement L
JOIN Reservation Res ON L.id_logement = Res.id_logement
JOIN Resident R ON Res.id_resident = R.id_resident
WHERE CURRENT_DATE BETWEEN Res.date_debut AND Res.date_fin
GROUP BY L.id_logement, L.emplacement;


-- trigger pour mettre à jour le statut du logement après une intervention :

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

-- Profil démographique des résidents :

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



