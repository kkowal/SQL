DROP SCHEMA IF EXISTS projet CASCADE;

CREATE SCHEMA projet;

CREATE TABLE projet.utilisateurs ( 
	login VARCHAR(50) PRIMARY KEY,
	email VARCHAR(100) NOT NULL UNIQUE,
	nom VARCHAR(100) NOT NULL CHECK (nom <> ''),
	prenom VARCHAR(100) NOT NULL CHECK(prenom <> ''),
	mdp VARCHAR(100) NOT NULL,
	nb_obj_vendus INTEGER NOT NULL DEFAULT 0,
	etat_user VARCHAR(15) CHECK(etat_user = 'actif' OR etat_user = 'suspendu' OR etat_user = 'supprimé') DEFAULT 'actif',
	derniere_eval INTEGER NULL,
	eval_moyenne NUMERIC NULL,
	nb_eval_total INTEGER NOT NULL DEFAULT 0 
);

CREATE TABLE projet.objets (
	id_objet SERIAL PRIMARY KEY,
	decription VARCHAR(1000) NOT NULL,
	prix_depart INTEGER NOT NULL CHECK(prix_depart >= 0),
	date_debut TIMESTAMP NOT NULL DEFAULT now(),
	date_fin TIMESTAMP NOT NULL DEFAULT now() + INTERVAL '15 days',
	etat VARCHAR (15) NOT NULL CHECK (etat = 'en vente' OR etat = 'vendu' OR etat = 'annulé') DEFAULT 'en vente',
	vendeur VARCHAR(50) REFERENCES projet.utilisateurs(login)
);

CREATE TABLE projet.encheres (
	id_enchere SERIAL PRIMARY KEY,
	etat VARCHAR(20) NOT NULL CHECK (etat = 'enchère remportée' OR etat = 'enchère perdue' OR etat = 'enchère annulée' 
						OR etat ='meilleure enchère' OR etat = 'enchère perdante'),
	prix INTEGER CHECK (prix >= 0),
	objet INTEGER REFERENCES projet.objets(id_objet),
	acheteur VARCHAR(50) REFERENCES projet.utilisateurs(login)
);

CREATE TABLE projet.transactions (
	enchere INTEGER REFERENCES projet.encheres(id_enchere),
	objet INTEGER REFERENCES projet.objets(id_objet)  PRIMARY KEY);

CREATE TABLE projet.evaluations (
	note_evaluation INTEGER NOT NULL CHECK (note_evaluation > 0 AND note_evaluation < 6),
	commentaire VARCHAR(500) NOT NULL,
	id_transaction INTEGER REFERENCES projet.transactions(objet),
	user_evaluer VARCHAR(50) REFERENCES projet.utilisateurs(login),
	CONSTRAINT eval_key PRIMARY KEY (id_transaction, user_evaluer)
);

CREATE OR REPLACE FUNCTION projet.creerUtilisateur(VARCHAR(50),VARCHAR(100), VARCHAR(100), VARCHAR(100),
	VARCHAR(100)) RETURNS VOID AS $$

DECLARE
	login_user ALIAS FOR $1;
	email_user ALIAS FOR $2;
	nom ALIAS FOR $3;
	prenom ALIAS FOR $4;
	mdp ALIAS FOR $5;

BEGIN 
	IF
		EXISTS (SELECT u.* 
			FROM projet.utilisateurs u
			WHERE u.login = login_user OR u.email = email_user) THEN 
		RAISE 'Ce login ou ce mail existe déjà!';
	END IF;

	INSERT INTO projet.utilisateurs VALUES
		(login_user, email_user, nom, prenom, mdp, DEFAULT, DEFAULT, NULL, NULL, DEFAULT);
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION projet.creerObjet(VARCHAR(1000), INTEGER, TIMESTAMP, VARCHAR(50)) RETURNS VOID AS $$
DECLARE 
	description ALIAS FOR $1;
	prix ALIAS FOR $2;
	date_fin ALIAS FOR $3;
	vendeur ALIAS FOR $4;

BEGIN
	IF 
		NOT EXISTS (SELECT u.*
			FROM projet.utilisateurs u
			WHERE u.login = vendeur) THEN
		RAISE 'L utilisateur n existe pas!';
	END IF;

	IF 
		(date_fin IS NULL)
		THEN INSERT INTO projet.objets VALUES (DEFAULT, description, prix, DEFAULT, DEFAULT, DEFAULT, vendeur);
	ELSE
		INSERT INTO projet.objets VALUES (DEFAULT, description, prix, DEFAULT, date_fin, DEFAULT, vendeur);
	END IF;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION projet.creerEnchere(INTEGER, INTEGER, VARCHAR(50)) RETURNS VOID AS $$
DECLARE
	prix ALIAS FOR $1;
	objet ALIAS FOR $2;
	acheteur ALIAS FOR $3;

BEGIN 
	IF 
		NOT EXISTS (SELECT o.*
				FROM projet.objets o
				WHERE o.id_objet = objet) THEN
		RAISE 'L objet n existe pas!';
	END IF;
	
	IF
		'en vente' != (SELECT o.etat
				FROM projet.objets o
				WHERE o.id_objet = objet) THEN
		RAISE 'Cet objet n est pas en vente!';
	END IF;

	IF 
		NOT EXISTS (SELECT u.*
				FROM projet.utilisateurs u
				WHERE u.login = acheteur) THEN
		RAISE 'L utlisateur n existe pas!';
	END IF;

	INSERT INTO projet.encheres VALUES (DEFAULT, 'meilleure enchère', prix, objet, acheteur);

END;
$$ LANGUAGE plpgsql;

CREATE FUNCTION projet.enchereTrigger() RETURNS TRIGGER AS $$
DECLARE
	prix INTEGER;

BEGIN 
	IF
		'en vente' != (SELECT o.etat
				FROM projet.objets o
				WHERE o.id_objet = NEW.objet) THEN 
			RAISE 'Ce produit n est plus en vente!';
	ELSE
		IF
			0 =  (SELECT count(e.*)
			    FROM projet.encheres e
			    WHERE e.objet = NEW.objet) THEN
			IF
					NEW.prix < (SELECT o.prix_depart
						    FROM projet.objets o
						    WHERE o.id_objet = NEW.objet) THEN
					RAISE 'Le prix n est pas plus grand que le prix de  départ!';
			END IF;
		ELSE 
			IF
				NEW.prix > (SELECT MAX(e.prix)
				    FROM projet.encheres e
				    WHERE e.objet = NEW.objet AND e.id_enchere != NEW.id_enchere) THEN
				UPDATE projet.encheres 
				SET etat = 'enchère perdante'
				WHERE objet = NEW.objet AND id_enchere != NEW.id_enchere;
			ELSE 
				RAISE 'Le prix n est pas plus grand que le prix de l ancienne enchère!';
			END IF;
		END IF;
	END IF;
	
	RETURN NEW;
END;
$$ LANGUAGE plpgsql;

SELECT projet.creerUtilisateur('Kamil', 'kamilkowal03@gmail.com', 'Kamil', 'Kowalczyk', 'k');
SELECT projet.creerUtilisateur('john', 'john@gmail.com', 'john', 'john', 'john');
SELECT projet.creerUtilisateur('d', 'd@gmail.com', 'john', 'john', 'john');
SELECT projet.creerUtilisateur('c', 'c@gmail.com', 'john', 'john', 'john');
SELECT projet.creerObjet('Canapés', 200, null,'Kamil');
SELECT projet.creerObjet('Livre', 50, null,'john');

CREATE TRIGGER trigger_enchere BEFORE INSERT ON projet.encheres 
	FOR EACH ROW EXECUTE PROCEDURE projet.enchereTrigger();
SELECT projet.creerEnchere(200, '1', 'john');
SELECT projet.creerEnchere(350, '1', 'd');
SELECT projet.creerEnchere(400, '1', 'c');
SELECT projet.creerEnchere(500, '1', 'john');
SELECT projet.creerEnchere(50, '2', 'Kamil');
SELECT projet.creerEnchere(60, '2', 'Kamil');
--SELECT projet.creerEnchere(160, '1', 'john');


	