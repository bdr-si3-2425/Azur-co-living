--DB RESET
DROP TABLE chambre;
DROP TABLE resident_conflicts;
DROP TABLE equipement;
DROP TABLE intervention;
DROP TABLE note;
DROP TABLE participation;
DROP TABLE reservation;
DROP TABLE type_intervention;
DROP TABLE evenement;
DROP TABLE logement;
DROP TABLE type_logement;
DROP TABLE conflit CASCADE;
DROP TABLE profil CASCADE;
DROP TABLE resident CASCADE;


--DB TABLE RECREATION
CREATE TABLE Type_logement (
    id_type_logement SERIAL PRIMARY KEY,
    type_logement VARCHAR(50) NOT NULL,
    charge_supplementaire FLOAT CHECK (charge_supplementaire >= 0)
);

CREATE TABLE Logement (
    id_logement SERIAL PRIMARY KEY,
    emplacement VARCHAR(100) NOT NULL,
    surface FLOAT CHECK (surface > 0),
    loyer FLOAT CHECK (loyer >= 0),
    nombre_chambres INT CHECK (nombre_chambres > 0),
    id_type_logement INT NOT NULL,
    CONSTRAINT fk__type_logement FOREIGN KEY (id_type_logement)
        REFERENCES Type_logement (id_type_logement)
        ON DELETE CASCADE
);
CREATE TABLE Equipement (
    id_equipement SERIAL PRIMARY KEY,
    nom_equipement VARCHAR(100) NOT NULL,
    etat VARCHAR(20) NOT NULL,
    id_logement INT NOT NULL,
    CONSTRAINT fk_logement FOREIGN KEY (id_logement)
        REFERENCES Logement (id_logement)
        ON DELETE CASCADE
);


CREATE TABLE Chambre (
    id_chambre SERIAL PRIMARY KEY,
	numero_chambre VARCHAR(10),
    etat VARCHAR(20) NOT NULL,
    id_logement INT NOT NULL,
	CONSTRAINT uq_chambre UNIQUE (id_logement, numero_chambre),--pour eviter des chambres en double dans un meme logement
    CONSTRAINT fk_logement_chambre FOREIGN KEY (id_logement)
        REFERENCES Logement (id_logement)
        ON DELETE CASCADE
);



CREATE TABLE Profil (
    id_profil SERIAL PRIMARY KEY,
    profession VARCHAR(100) NOT NULL,
    secteur_activite VARCHAR(100) NOT NULL
    
);

CREATE TABLE Resident (
    id_resident SERIAL PRIMARY KEY,
    nom VARCHAR(50) NOT NULL,
    prenom VARCHAR(50) NOT NULL,
    date_naissance DATE NOT NULL,
    cin VARCHAR(20) UNIQUE NOT NULL,
    date_entree DATE NOT NULL,
    date_sortie DATE,
    id_profil INT NOT NULL,
    CONSTRAINT fk_id_profil FOREIGN KEY (id_profil)
        REFERENCES Profil (id_profil)
        ON DELETE CASCADE
);


CREATE TABLE Reservation (
    id_reservation SERIAL PRIMARY KEY,
    date_debut DATE NOT NULL,
    date_fin DATE CHECK (date_fin >= date_debut),
    id_logement INT NOT NULL,
    id_resident INT NOT NULL,
    CONSTRAINT fk_logement_reservation FOREIGN KEY (id_logement)
        REFERENCES Logement (id_logement)
        ON DELETE CASCADE,
    CONSTRAINT fk_resident_reservation FOREIGN KEY (id_resident)
        REFERENCES Resident (id_resident)
        ON DELETE CASCADE
);


CREATE TABLE Type_intervention (
    id_type_intervention SERIAL PRIMARY KEY,
    type_intervention VARCHAR(50) NOT NULL,
    description TEXT
);


CREATE TABLE Intervention (
    id_intervention SERIAL PRIMARY KEY,
    description TEXT,
    id_type_intervention INT NOT NULL,
    CONSTRAINT fk_id_type_intervention FOREIGN KEY (id_type_intervention)
        REFERENCES Type_intervention (id_type_intervention)
        ON DELETE CASCADE
);



CREATE TABLE Conflit (
    id_conflit SERIAL PRIMARY KEY,
    description TEXT NOT NULL,
    resolu VARCHAR(10) CHECK (resolu in ('oui', 'En cours','non')),
    date_conflit DATE NOT NULL,
    id_resident INT NOT NULL,
	CONSTRAINT fk_id_resident FOREIGN KEY (id_resident) REFERENCES Resident(id_resident) ON DELETE CASCADE
);


CREATE TABLE Resident_conflicts (
    id_conflit INT NOT NULL,
    id_resident INT NOT NULL,
	PRIMARY KEY (id_conflit, id_resident),
    role_resident VARCHAR(10) check ( role_resident in ('initiateur', 'accuse', 'temoin') ),
    FOREIGN KEY (id_conflit) REFERENCES Conflit(id_conflit) ON DELETE CASCADE,
    FOREIGN KEY (id_resident) REFERENCES Resident(id_resident) ON DELETE CASCADE
);


CREATE TABLE Evenement (
    id_evenement SERIAL PRIMARY KEY,
    type_evenement VARCHAR(50) NOT NULL,
    date_event DATE NOT NULL
);

CREATE TABLE Participation (
    id_resident INT NOT NULL,
    id_evenement INT NOT NULL,
    PRIMARY KEY (id_resident, id_evenement),
    CONSTRAINT fk_participation_resident FOREIGN KEY (id_resident)
        REFERENCES Resident (id_resident)
        ON DELETE CASCADE,
    CONSTRAINT fk_participation_evenement FOREIGN KEY (id_evenement)
        REFERENCES Evenement (id_evenement)
        ON DELETE CASCADE
);
CREATE TABLE Note (
    id_note SERIAL PRIMARY KEY,
    id_logement INT NOT NULL,
    id_resident INT NOT NULL,
    score INT CHECK (score BETWEEN 1 AND 5),
    commentaire TEXT,
    date_note DATE NOT NULL DEFAULT CURRENT_DATE,
    CONSTRAINT fk_note_logement FOREIGN KEY (id_logement)
        REFERENCES Logement (id_logement)
        ON DELETE CASCADE,
    CONSTRAINT fk_note_resident FOREIGN KEY (id_resident)
        REFERENCES Resident (id_resident)
        ON DELETE CASCADE
);

