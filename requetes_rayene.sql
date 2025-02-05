--selection de personnes partageant un meme logement avec une reservation en cours
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


--Selection de tout les résident qui ont deja partagé ou qui partage encore un logement
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

--selection des logements les plus demandées
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

-- Retourne les 3 mois avec le plus de réservations
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

--changement de prix d'un logement donné
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

--création automatique des factures
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
