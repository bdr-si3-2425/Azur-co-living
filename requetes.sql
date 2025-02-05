-------------------
-------RAJAA-------
-------------------

--ceci permet d'inserer automatiquement une ligne dans la table facture lorqu'une reservation est inserée
CREATE OR REPLACE FUNCTION insert_facture_on_reservation()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO facture (cin_personne, prix_total, id_reservation)
    VALUES (
        (SELECT cin FROM Resident WHERE id_resident = NEW.id_resident),
        500.00,  -- Prix par défaut (tu peux le calculer autrement)
        NEW.id_reservation
    );
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

--trigger qui sera declenche a chaque insertion dans reservation
CREATE TRIGGER trigger_insert_facture
AFTER INSERT ON Reservation
FOR EACH ROW
EXECUTE FUNCTION insert_facture_on_reservation();

--insertion d'une reservation
INSERT INTO Reservation (id_reservation,date_debut, date_fin, id_logement, id_resident)
VALUES (39,'2025-02-05', '2025-03-05', 1, 1);

--verification de la table facture
select * from facture




-- 1 Quels logements sont disponibles pour une période donnée, selon des critères spécifiques (type, emplacement, prix) ?
-- Pocedure stockée
CREATE OR REPLACE PROCEDURE logements_disponibles(
    IN p_date_debut DATE,
    IN p_date_fin DATE,
    IN p_type_logement VARCHAR(50),
    IN p_emplacement VARCHAR(100),
    IN p_loyer_max FLOAT
)
LANGUAGE plpgsql
AS $$
BEGIN
    -- Création d'une table temporaire pour stocker les résultats
    CREATE TEMP TABLE temp_logements_disponibles AS 
    SELECT l.id_logement, l.emplacement, l.loyer, t.type_logement
    FROM Logement l
    JOIN Type_logement t ON l.id_type_logement = t.id_type_logement
    WHERE l.etat = 'Disponible'
    AND (p_type_logement IS NULL OR t.type_logement ILIKE p_type_logement)
    AND (p_emplacement IS NULL OR l.emplacement ILIKE p_emplacement)
    AND (p_loyer_max IS NULL OR l.loyer <= p_loyer_max)
    AND l.id_logement NOT IN (
        SELECT id_logement FROM Reservation 
        WHERE (date_debut, date_fin) OVERLAPS (p_date_debut, p_date_fin)
    );
END;
$$;
--exemple d'utilisation
CALL logements_disponibles('2025-03-01', '2025-03-15', 'Appartement', 'Paris', 1500);
SELECT * FROM temp_logements_disponibles;



-- 2-Comment gérer les réservations et attribuer les logements aux nouveaux résidents en optimisant l’occupation ?
-- Procedure stockee
CREATE OR REPLACE PROCEDURE attribuer_logement(
    IN p_id_resident INT,
    IN p_date_debut DATE,
    IN p_date_fin DATE,
    OUT v_id_logement INT
)
LANGUAGE plpgsql
AS $$
BEGIN
    -- Sélection du logement disponible le moins cher
    SELECT id_logement INTO v_id_logement
    FROM Logement l
    WHERE l.etat = 'Disponible'
    AND l.id_logement NOT IN (
        SELECT id_logement FROM Reservation 
        WHERE (date_debut, date_fin) OVERLAPS (p_date_debut, p_date_fin)
    )
    ORDER BY l.loyer ASC 
    LIMIT 1;

    -- Vérification de la disponibilité d'un logement
    IF v_id_logement IS NULL THEN
        RAISE EXCEPTION 'Aucun logement disponible pour cette période';
    END IF;

    -- Création de la réservation
    INSERT INTO Reservation (date_debut, date_fin, id_logement, id_resident)
    VALUES (p_date_debut, p_date_fin, v_id_logement, p_id_resident);

    -- Mise à jour de l'état du logement
    UPDATE Logement 
    SET etat = 'Occupé' 
    WHERE id_logement = v_id_logement;
    
    -- Affichage du logement attribué
    RAISE NOTICE 'Logement % attribué au résident %', v_id_logement, p_id_resident;
END;
$$;


--exemple d'utilisation
CALL attribuer_logement(5, '2025-03-01', '2025-03-15', NULL);






-- 3- Quel est le taux d'occupation actuel des logements ?
SELECT 
    (COUNT(DISTINCT r.id_logement)::FLOAT / COUNT(l.id_logement)) * 100 AS taux_occupation
FROM 
    Logement l
LEFT JOIN 
    Reservation r ON r.id_logement = l.id_logement
    AND r.date_fin >= CURRENT_DATE;




-- 4- Quel est le temps moyen de séjour d'un résident dans un logement ?
SELECT 
    AVG(DATE_PART('day', r.date_fin - r.date_debut)) AS temps_moyen_sejour
FROM 
    Reservation r;



-- 5- Quel est le profil des résidents qui prolongent leur séjour par rapport à ceux qui ne prolongent pas ?

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





-- 6- Quelles sont les tendances de réservation sur différentes périodes (mois, trimestre, année) ?
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





-- 7- Combien de résidents sont inscrits dans des activités régulières (cours, événements, etc.) ?
SELECT COUNT(DISTINCT id_resident) AS nb_residents_actifs 
FROM Participation;




-- 8- Comment les saisons affectent-elles la demande des logements ?
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


-------------------
----ASSIA---------
--------------------
    
  -- 9 Quels logements ont le meilleur rapport qualité/prix en fonction des avis des résidents ?
  
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

-- 12. Quels sont les types de logements les plus rentables ?

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

-- 13 Quels résidents ont eu des comportements problématiques ou signalés des conflits récurrents ?

SELECT r.nom, r.prenom, COUNT(c.id_conflit) AS nombre_conflits
FROM Resident r
JOIN Resident_conflicts rc ON r.id_resident = rc.id_resident
JOIN Conflit c ON rc.id_conflit = c.id_conflit
WHERE c.resolu != 'oui'  
GROUP BY r.id_resident
HAVING COUNT(c.id_conflit) > 1  
ORDER BY nombre_conflits DESC;

-- 14. Comment organiser les événements communautaires pour maximiser la participation des résidents dans un logement donné ?

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

-- 15 Liste des logements disponibles pour une période spécifique
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

-- 16 Liste des résidents ayant prolongé leur séjour :

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

-- 17 Liste des logements avec le nombre de demandes en attente 

SELECT L.id_logement, 
       L.emplacement,
       COUNT(R.id_reservation) AS nb_demandes_attente
FROM Logement L
LEFT JOIN Reservation R ON L.id_logement = R.id_logement
WHERE R.date_fin >= CURRENT_DATE
GROUP BY L.id_logement, L.emplacement
ORDER BY nb_demandes_attente DESC;

-- 18 Liste des logements avec le nombre d'interventions et la moyenne des notes :

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

-- 19 Liste des logements avec le nombre de résidents actifs :


SELECT L.id_logement, L.emplacement, COUNT(DISTINCT R.id_resident) AS nb_residents
FROM Logement L
JOIN Reservation Res ON L.id_logement = Res.id_logement
JOIN Resident R ON Res.id_resident = R.id_resident
WHERE CURRENT_DATE BETWEEN Res.date_debut AND Res.date_fin
GROUP BY L.id_logement, L.emplacement;


-- 20 trigger pour mettre à jour le statut du logement après une intervention :

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
-- 21 Création de fonction et trigger pour libérer le logement après une annulation de réservation :

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

-- 22 Profil démographique des résidents :

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





-----------------------
------RAYEN------------
-----------------------

--23 selection de personnes partageant un meme logement avec une reservation en cours
SELECT 
    re.id_logement,
    r.nom,
    r.prenom,
    e.type_evenement as evenement,
    con.description as conflit
FROM 
    Resident AS r
JOIN 
    Reservation AS re ON r.id_resident = re.id_resident
LEFT JOIN 
    resident_conflicts AS rc ON r.id_resident = rc.id_resident
LEFT JOIN 
    Conflit AS con ON rc.id_conflit = con.id_conflit
LEFT JOIN 
    Participation AS p ON p.id_resident = r.id_resident
LEFT JOIN 
    evenement AS e ON e.id_evenement = p.id_evenement
WHERE 
    CURRENT_DATE BETWEEN re.date_debut AND re.date_fin -- Réservation active
    AND re.id_logement IN (
        SELECT re2.id_logement
        FROM Reservation AS re2
        WHERE CURRENT_DATE BETWEEN re2.date_debut AND re2.date_fin
        GROUP BY re2.id_logement
        HAVING COUNT(DISTINCT re2.id_resident) > 1 -- verification qu'il y a plus de 2 personnes dans un meme logement
    );


--24 Selection de tout les résident qui ont deja partagé ou qui partage encore un logement
SELECT 
    re.id_logement,
    STRING_AGG(r.nom || ' ' || r.prenom, ', ') AS residents,
    COUNT(*) AS nombre_residents
FROM 
    Resident AS r
JOIN 
    Reservation AS re ON r.id_resident = re.id_resident
WHERE 
    EXISTS (
        SELECT 1
        FROM Reservation AS re2
        WHERE re2.id_logement = re.id_logement
          AND re2.id_resident != r.id_resident
          AND (
              (re.date_debut <= re2.date_fin AND re.date_fin >= re2.date_debut)
              OR 
              (re2.date_debut <= re.date_fin AND re2.date_fin >= re.date_debut) 
          )
    )
GROUP BY 
    re.id_logement
HAVING 
    COUNT(*) > 1;

--
WITH logement_reservations AS (
    SELECT 
        re.id_logement,
        COUNT(*) AS nombre_reservations,
        AVG(n.score) AS note_generale
    FROM 
        Reservation AS re
    LEFT JOIN 
        note AS n ON re.id_logement = n.id_logement
    GROUP BY 
        re.id_logement
)

-- 25 selection des logements les plus demandées
WITH logement_reservations AS (
    SELECT 
        re.id_logement,
        COUNT(*) AS nombre_reservations,
        AVG(COALESCE(n.score, 0)) AS note_generale -- Remplace NULL par 0
    FROM 
        Reservation AS re
    LEFT JOIN 
        note AS n ON re.id_logement = n.id_logement
    GROUP BY  
        re.id_logement
)
SELECT 
    lr.id_logement,
    lr.nombre_reservations,
    lr.note_generale,
    l.emplacement,
    l.surface,
    l.loyer,
    l.nombre_chambres
FROM 
    logement_reservations AS lr
JOIN 
    logement AS l ON lr.id_logement = l.id_logement
ORDER BY 
    lr.nombre_reservations DESC, 
    lr.note_generale DESC
LIMIT 3;

-- 26 Retourne les 3 mois avec le plus de réservations
WITH reservations_par_mois AS (
    SELECT 
        TO_CHAR(date_debut, 'MM') AS mois,
        COUNT(*) AS nombre_reservations
    FROM 
        Reservation
    GROUP BY 
        TO_CHAR(date_debut, 'MM')
)
SELECT 
    mois,
    nombre_reservations
FROM 
    reservations_par_mois
ORDER BY 
    nombre_reservations DESC
LIMIT 3;

-- 27 changement de prix d'un logement donné
BEGIN;

UPDATE logement 
SET loyer = 700 
WHERE id_logement = 10;
UPDATE facture 
SET prix_total = 700 * (r.date_fin - r.date_debut)
FROM Reservation r
WHERE facture.id_reservation = r.id_reservation
AND r.id_logement = 10;

COMMIT;

-- 28 .création automatique des factures
INSERT INTO facture (cin_personne, prix_total, id_reservation)
SELECT 
    r.cin AS cin_personne,
    (lg.loyer * (re.date_fin - re.date_debut)) AS prix_total,
    re.id_reservation
FROM 
    Reservation re
JOIN 
    Resident r ON re.id_resident = r.id_resident
JOIN 
    logement lg ON re.id_logement = lg.id_logement;
