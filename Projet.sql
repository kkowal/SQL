DROP SCHEMA IF EXISTS projet CASCADE;

CREATE SCHEMA projet;

CREATE TABLE projet.utilisateurs ( 
	login VARCHAR(50) PRIMARY KEY,
	email VARCHAR(100) NOT NULL UNIQUE,
	nom VARCHAR(100) NOT NULL CHECK (nom <> ''),
	prenom VARCHAR(100) NOT NULL CHECK(prenom <> ''),
	mdp VARCHAR(100) NOT NULL,
	nb_obj_vendus INTEGER NOT NULL DEFAULT 0,
	administrateur BOOLEAN DEFAULT false,
	suspendu BOOLEAN DEFAULT false,
	derniere_eval INTEGER NULL,
	eval_moyenne NUMERIC NULL,
	nb_eval_total INTEGER NOT NULL DEFAULT 0 
);

CREATE TABLE projet.objets (
	id_objet SERIAL PRIMARY KEY,
	decription VARCHAR(1000) NOT NULL,
	prix_depart INTEGER NOT NULL CHECK(prix_depart > 0),
	date_debut TIMESTAMP NOT NULL DEFAULT now(),
	-- Voir s'il est possible de faire date_debut + 15
	date_fin TIMESTAMP NOT NULL,
	-- Voir comment faire une liste énumérée pour l'état
	etat VARCHAR (15) NOT NULL DEFAULT 'en vente',
	vendeur VARCHAR(50) REFERENCES projet.utilisateurs(login)
);

CREATE TABLE projet.encheres (
	id_enchere SERIAL PRIMARY KEY,
	-- Voir comment faire une liste énumérée pour l'état
	etat VARCHAR(20) NOT NULL,
	-- Voir si possible de checker si le prix >= prix_depart
	prix INTEGER CHECK (prix >= 0),
	objet INTEGER REFERENCES projet.objets(id_objet),
	acheteur VARCHAR(50) REFERENCES projet.utilisateurs(login)
);

CREATE TABLE projet.transactions (
	id_transaction SERIAL PRIMARY KEY,
	enchere INTEGER REFERENCES projet.encheres(id_enchere),
	objet INTEGER REFERENCES projet.objets(id_objet)
);

CREATE TABLE projet.evaluations (
	note_evaluation INTEGER NOT NULL CHECK (note_evaluation > 0) CHECK (note_evaluation < 6),
	commentaire VARCHAR(500) NOT NULL,
	id_transaction INTEGER REFERENCES projet.transactions(id_transaction),
	user_evaluer VARCHAR(50) REFERENCES projet.utilisateurs(login),
	CONSTRAINT eval_key PRIMARY KEY (id_transaction, user_evaluer)
);

CREATE OR REPLACE FUNCTION projet.creerUtilisateur(VARCHAR(50),VARCHAR(100), VARCHAR(100), VARCHAR(100),
	VARCHAR(100), BOOLEAN) RETURNS VOID AS $$

DECLARE
	login_user ALIAS FOR $1;
	email_user ALIAS FOR $2;
	nom ALIAS FOR $3;
	prenom ALIAS FOR $4;
	mdp ALIAS FOR $5;
	administrateur ALIAS FOR $6;

BEGIN 
	IF
		EXISTS (SELECT u.* 
			FROM projet.utilisateurs u
			WHERE u.login = login_user OR u.email = email_user) THEN 
		RAISE 'Ce login ou ce mail existe déjà!';
	END IF;

	INSERT INTO projet.utilisateurs VALUES
		(login_user, email_user, nom, prenom, mdp, DEFAULT, administrateur, DEFAULT, NULL, NULL, DEFAULT);
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION projet.creerObjet(VARCHAR(1000), INTEGER,  VARCHAR(50)) RETURNS VOID AS $$
DECLARE 
	description ALIAS FOR $1;
	prix ALIAS FOR $2;
	--date_debut ALIAS FOR $3;
	--date_fin ALIAS FOR $4;
	vendeur ALIAS FOR $3;

BEGIN
	IF 
		NOT EXISTS (SELECT u.*
			FROM projet.utilisateurs u
			WHERE u.login = vendeur) THEN
		RAISE 'L utilisateur n existe pas!';
	END IF;
	
	INSERT INTO projet.objets VALUES (DEFAULT, description, prix, now(), now(), DEFAULT, vendeur);
END;
$$ LANGUAGE plpgsql;

SELECT projet.creerUtilisateur('Kamil', 'kamilkowal03@gmail.com', 'Kamil', 'Kowalczyk', 'kowal', 'true');
SELECT projet.creerObjet('Canapés', 200, 'Kamil');


	