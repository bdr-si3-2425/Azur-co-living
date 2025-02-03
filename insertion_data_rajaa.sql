-- Insertion des types de logement
INSERT INTO Type_logement (type_logement, charge_supplementaire) VALUES
('Studio', 0),
('Appartement T2', 20),
('Appartement T3', 30),
('Maison', 50);
select * from type_logement

-- Insertion des logements
INSERT INTO Logement (emplacement, surface, loyer, nombre_chambres, id_type_logement) VALUES
('Rue de la Paix, Paris', 30, 700, 1, 1),
('Avenue des Champs, Paris', 50, 1200, 2, 2),
('Boulevard Haussmann, Paris', 80, 2000, 3, 3),
('Rue Nationale, Lyon', 100, 2500, 4, 4);

-- Insertion des équipements
INSERT INTO Equipement (nom_equipement, etat, id_logement) VALUES
('Climatisation', 'Bon', 1),
('Lave-linge', 'Usé', 2),
('Four', 'Neuf', 3),
('Chauffage', 'Bon', 4);

-- Insertion des chambres
INSERT INTO Chambre (numero_chambre, etat, id_logement) VALUES
('101', 'Libre', 1),
('102', 'Occupée', 1),
('201', 'Libre', 2),
('301', 'Occupée', 3);

-- Insertion des profils des résidents
INSERT INTO Profil (profession, secteur_activite) VALUES
('Ingénieur', 'Informatique'),
('Médecin', 'Santé'),
('Professeur', 'Éducation'),
('Comptable', 'Finance');

-- Insertion des résidents
INSERT INTO Resident (nom, prenom, date_naissance, cin, date_entree, date_sortie, id_profil) VALUES
('Dupont', 'Jean', '1985-06-15', '123456789', '2023-01-01', NULL, 1),
('Martin', 'Sophie', '1992-08-20', '987654321', '2022-12-01', '2023-12-31', 2),
('Lefevre', 'Paul', '1990-03-10', '456789123', '2023-02-01', NULL, 3);

-- Insertion des réservations
INSERT INTO Reservation (date_debut, date_fin, id_logement, id_resident) VALUES
('2024-01-01', '2024-06-30', 1, 1),
('2024-02-01', '2024-12-31', 2, 2),
('2024-03-01', '2024-09-30', 3, 3);

-- Insertion des types d'intervention
INSERT INTO Type_intervention (type_intervention, description) VALUES
('Plomberie', 'Fuite deau'),
('Électricité', 'Panne de courant'),
('Chauffage', 'Problème de chaudière');

-- Insertion des interventions
INSERT INTO Intervention (description, id_type_intervention, id_logement) VALUES
('Réparation de tuyaux', 1, 1),
('Installation dun nouveau disjoncteur', 2, 2);

-- Insertion des conflits
INSERT INTO Conflit (description, resolu, date_conflit, id_resident) VALUES
('Dispute sur le bruit', 'non', '2024-07-10', 1),
('Dégradation déquipement', 'oui', '2024-05-15', 2);

-- Insertion des conflits et résidents impliqués
INSERT INTO Resident_conflicts (id_conflit, id_resident, role_resident) VALUES
(1, 1, 'initiateur'),
(1, 2, 'accuse'),
(2, 3, 'temoin');

-- Insertion des événements
INSERT INTO Evenement (type_evenement, date_event) VALUES
('Fête des voisins', '2024-06-15'),
('Réunion des locataires', '2024-09-10');

-- Insertion des participations aux événements
INSERT INTO Participation (id_resident, id_evenement) VALUES
(1, 1),
(2, 1),
(3, 2);

-- Insertion des notes des logements
INSERT INTO Note (id_logement, id_resident, score, commentaire, date_note) VALUES
(1, 1, 4, 'Bon logement', '2024-07-01'),
(2, 2, 5, 'Super appartement', '2024-08-01'),
(3, 3, 3, 'Un peu bruyant', '2024-09-01');

-- Insertion des factures
INSERT INTO Facture (cin_personne, prix_total, id_reservation) VALUES
('123456789', 1400.00, 1),
('987654321', 3600.00, 2);

-- Association des logements et équipements
INSERT INTO Logement_Equipement (id_logement, id_equipement) VALUES
(1, 1),
(2, 2),
(3, 3),
(4, 4);

-- Association des logements et interventions
INSERT INTO Logement_Intervention (id_logement, id_intervention) VALUES
(1, 1),
(2, 2);

-- Association des réservations et résidents
INSERT INTO Reservation_Resident (id_reservation, id_resident) VALUES
(1, 1),
(2, 2),
(3, 3);

-- Association des résidents et conflits
INSERT INTO Resident_Conflit (id_resident, id_conflit) VALUES
(1, 1),
(2, 2);

-- Association des interventions et types d'intervention
INSERT INTO Intervention_TypeIntervention (id_intervention, id_type_intervention) VALUES
(1, 1),
(2, 2);

-- Association des résidents et événements
INSERT INTO Resident_Evenement (id_resident, id_evenement) VALUES
(1, 1),
(2, 2);

-- Association des logements et notes
INSERT INTO Logement_Note (id_logement, id_note) VALUES
(1, 1),
(2, 2),
(3, 3);


SELECT * FROM Logement;
SELECT * FROM Reservation;
SELECT * FROM Resident;
SELECT * FROM Facture;

