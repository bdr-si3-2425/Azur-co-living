-- requete A

SELECT 
    l.id_logement,
    l.emplacement,
    l.surface,
    l.loyer,
    l.nombre_chambres,
    t.type_logement,
    t.charge_supplementaire
FROM Logement l
JOIN Type_logement t ON l.id_type_logement = t.id_type_logement
WHERE l.id_logement NOT IN (
    SELECT r.id_logement
    FROM Reservation r
    WHERE 
        (r.date_debut <= '2025-02-10' AND r.date_fin >= '2025-02-01')  -- Vérifie les conflits de réservation
)
AND ('Appartement' IS NULL OR t.type_logement = 'Appartement')
AND ('Paris' IS NULL OR l.emplacement = 'Paris')
AND (1200 IS NULL OR l.loyer <= 1200);