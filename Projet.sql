﻿DROP SCHEMA IF EXISTS projet CASCADE;

CREATE SCHEMA projet;

		----------------------------
		-------CREATION TABLE-------
		----------------------------
		
-- Création de la table utilisateurs
CREATE TABLE projet.utilisateurs ( 
	login VARCHAR(50) PRIMARY KEY,
	email VARCHAR(100) NOT NULL UNIQUE CHECK (email <> ''),
	nom VARCHAR(100) NOT NULL CHECK (nom <> ''),
	prenom VARCHAR(100) NOT NULL CHECK (prenom <> ''),
	mdp VARCHAR(100) NOT NULL CHECK (mdp <> ''),
	nb_obj_vendus INTEGER NOT NULL DEFAULT 0,
	etat_user VARCHAR(15) CHECK(etat_user = 'actif' OR etat_user = 'suspendu' OR etat_user = 'supprimé') DEFAULT 'actif',
	derniere_eval INTEGER NULL,
	eval_moyenne NUMERIC NULL,
	nb_eval_total INTEGER NOT NULL DEFAULT 0 
);

-- Création de la table objets
CREATE TABLE projet.objets (
	id_objet SERIAL PRIMARY KEY,
	description VARCHAR(1000) NOT NULL CHECK (description <> ''),
	prix_depart INTEGER NOT NULL CHECK(prix_depart > 0),
	date_debut TIMESTAMP NOT NULL DEFAULT now(),
	date_fin TIMESTAMP NOT NULL CHECK (date_fin >= now())DEFAULT now() + INTERVAL '15 days',
	etat VARCHAR (15) NOT NULL CHECK (etat = 'en vente' OR etat = 'vendu' OR etat = 'annulé') DEFAULT 'en vente',
	vendeur VARCHAR(50) REFERENCES projet.utilisateurs(login)
);

-- Création de la table enchères
CREATE TABLE projet.encheres (
	id_enchere SERIAL PRIMARY KEY,
	etat VARCHAR(20) NOT NULL CHECK (etat = 'enchère remportée' OR etat = 'enchère perdue' OR etat = 'enchère annulée' 
						OR etat ='meilleure enchère' OR etat = 'enchère perdante'),
	prix INTEGER CHECK (prix >= 0),
	objet INTEGER REFERENCES projet.objets(id_objet),
	acheteur VARCHAR(50) REFERENCES projet.utilisateurs(login)
);

-- Création de la table transaction
CREATE TABLE projet.transactions (
	enchere INTEGER REFERENCES projet.encheres(id_enchere),
	objet INTEGER REFERENCES projet.objets(id_objet)  PRIMARY KEY);

-- Création de la table évaluations
CREATE TABLE projet.evaluations (
	note_evaluation INTEGER NOT NULL CHECK (note_evaluation > 0 AND note_evaluation < 6),
	commentaire VARCHAR(500) NOT NULL,
	id_transaction INTEGER REFERENCES projet.transactions(objet),
	user_evaluer VARCHAR(50) REFERENCES projet.utilisateurs(login),
	CONSTRAINT eval_key PRIMARY KEY (id_transaction, user_evaluer)
);

		----------------------------
		-----CREATION FONCTION------
		----------------------------	
		
-- Fonction qui permet la création d'un utilisateur
CREATE OR REPLACE FUNCTION projet.creerUtilisateur(VARCHAR(50),VARCHAR(100), VARCHAR(100), VARCHAR(100),
	VARCHAR(100)) RETURNS VOID AS $$

DECLARE
	login_user ALIAS FOR $1;
	email_user ALIAS FOR $2;
	nom ALIAS FOR $3;
	prenom ALIAS FOR $4;
	mdp ALIAS FOR $5;

BEGIN 

	INSERT INTO projet.utilisateurs VALUES
		(login_user, email_user, nom, prenom, mdp, DEFAULT, DEFAULT, NULL, NULL, DEFAULT);
END;
$$ LANGUAGE plpgsql;

-- Fonction qui permet la création d'un objet
CREATE OR REPLACE FUNCTION projet.creerObjet(VARCHAR(1000), INTEGER, TIMESTAMP, VARCHAR(50)) RETURNS VOID AS $$
DECLARE 
	description ALIAS FOR $1;
	prix ALIAS FOR $2;
	date_fin ALIAS FOR $3;
	vendeur ALIAS FOR $4;

BEGIN

	IF 
		(date_fin IS NULL)
		THEN INSERT INTO projet.objets VALUES (DEFAULT, description, prix, DEFAULT, DEFAULT, DEFAULT, vendeur);
	ELSE
		INSERT INTO projet.objets VALUES (DEFAULT, description, prix, DEFAULT, date_fin, DEFAULT, vendeur);
	END IF;
END;
$$ LANGUAGE plpgsql;

-- Fonction qui permet la création d'une enchère
CREATE OR REPLACE FUNCTION projet.creerEnchere(INTEGER, INTEGER, VARCHAR(50)) RETURNS VOID AS $$
DECLARE
	prix ALIAS FOR $1;
	objet ALIAS FOR $2;
	acheteur ALIAS FOR $3;

BEGIN 

	INSERT INTO projet.encheres VALUES (DEFAULT, 'meilleure enchère', prix, objet, acheteur);

END;
$$ LANGUAGE plpgsql;

-- Fonction qui permet de créer une nouvelle transaction
CREATE OR REPLACE FUNCTION projet.creerTransaction(INTEGER, INTEGER) RETURNS VOID AS $$
DECLARE 
	enchere ALIAS FOR $1;
	objet ALIAS FOR $2;
	login_vendeur VARCHAR(50);
BEGIN
	
	INSERT INTO projet.transactions VALUES (enchere, objet);
	
	SELECT vendeur
	FROM projet.objets
	WHERE id_objet = objet INTO login_vendeur;

	UPDATE projet.utilisateurs
	SET nb_obj_vendus = nb_obj_vendus + 1
	WHERE login = login_vendeur;
	
END;
$$LANGUAGE plpgsql;

-- Fonction qui permet d'émettre une évaluation à un utilisateur
CREATE OR REPLACE FUNCTION projet.creerEvaluation(INTEGER, VARCHAR(500), INTEGER, VARCHAR(20)) RETURNS VOID AS $$

DECLARE
	note ALIAS FOR $1;
	com ALIAS FOR $2;
	trans ALIAS FOR $3;
	utilisateur ALIAS FOR $4;

BEGIN
	INSERT INTO projet.evaluations VALUES (note, com, trans, utilisateur);
END;
$$LANGUAGE plpgsql;

		----------------------------
		-------MODIFICATION---------
		----------------------------
		
-- Fonction qui permet de faire la modification de l'objet	
CREATE OR REPLACE FUNCTION projet.modifierObjet(INTEGER, VARCHAR(50), INTEGER, VARCHAR(1000), TIMESTAMP) RETURNS VOID AS $$
DECLARE
	objet ALIAS FOR $1;
	proprio ALIAS FOR $2;
	n_prix ALIAS FOR $3;
	n_description ALIAS FOR $4;
	n_date_fin ALIAS FOR $5;

BEGIN
	IF
		(n_prix = 0) THEN
		SELECT prix_depart
		FROM projet.objets 
		WHERE id_objet = objet AND vendeur = proprio INTO n_prix;
	END IF; 
	IF
		(n_description IS NULL) THEN
		Select description
		FROM projet.objets 
		WHERE id_objet = objet AND vendeur = proprio INTO n_description;
	END IF; 
	IF
		(n_date_fin IS NOT NULL) THEN
		UPDATE projet.objets
		SET prix_depart = n_prix, description = n_description, date_fin = n_date_fin
		WHERE id_objet = objet AND vendeur = proprio;
	ELSE
		IF 
			(n_date_fin IS NULL) THEN
			SELECT date_debut
			FROM projet.objets 
			WHERE id_objet = objet AND vendeur = proprio INTO n_date_fin;
			n_date_fin = n_date_fin + INTERVAL '15 days';
			UPDATE projet.objets
			SET prix_depart = n_prix, description = n_description, date_fin = n_date_fin
			WHERE id_objet = objet AND vendeur = proprio;
		END IF;
	END IF; 
	
END;
$$LANGUAGE plpgsql;

-- Fonction qui permet à l'admin de modifier l'état de l'utilisateur s'il est suspendu
-- Donc le rendre en actif ou le supprimer
CREATE OR REPLACE FUNCTION projet.modifierEtatUser(VARCHAR(50), VARCHAR(20)) RETURNS VOID AS $$

DECLARE
	login_user ALIAS FOR $1;
	etat ALIAS FOR $2;

BEGIN
	IF
		'suspendu' = (SELECT u.etat_user
				FROM projet.utilisateurs u
				WHERE u.login = login_user) THEN
		UPDATE projet.utilisateurs
		SET etat_user = etat
		WHERE login = login_user;
	END IF;
END;
$$LANGUAGE plpgsql;


		----------------------------
		----------TRIGGER-----------
		----------------------------	

-- Trigger qui permet de vérifier s'il est possible de modifier un objet. 
-- Si une enchère existe pour un objet alors, impossible de le modifier. 
CREATE FUNCTION projet.modificationObjetTrigger() RETURNS TRIGGER AS $$
DECLARE

BEGIN
	IF
		EXISTS (SELECT e.*
			FROM projet.encheres e
			WHERE e.objet = NEW.id_objet AND (e.etat != 'enchère remportée' AND e.etat != 'enchère perdue' AND e.etat != 'enchère annulée')) THEN
		RAISE 'Une enchère existe! Impossible de modifier cet objet!';
	END IF;
	RETURN NEW;
END;
$$LANGUAGE plpgsql;

-- Trigger qui permet de vérifier si une transaction peut être réalisée
CREATE FUNCTION projet.transactionTrigger() RETURNS TRIGGER AS $$
DECLARE
BEGIN
	
	IF
		'meilleure enchère' != (SELECT e.etat
				FROM projet.encheres e
				WHERE e.id_enchere = NEW.enchere) THEN
		RAISE 'Cette enchère n a pas gagné l enchère!';
	END IF;

	IF
		'en vente' != (SELECT o.etat
			FROM projet.objets o
			WHERE o.id_objet = NEW.objet) THEN
		RAISE 'L objet ne peut pas être vendu! La transaction est annulée!';
	END IF;

	-- Mettre à jour l'état de l'enchère
		UPDATE projet.encheres
		SET etat = 'enchère remportée'
		WHERE id_enchere = NEW.enchere;

		UPDATE projet.encheres
		SET etat = 'enchère perdue'
		WHERE id_enchere != NEW.enchere AND objet = NEW.objet;

	-- Mettre à jour l'état de l'objet
		UPDATE projet.objets
		SET etat = 'vendu'
		WHERE id_objet = NEW.objet;
	RETURN NEW;
END;
$$LANGUAGE plpgsql;


-- Trigger qui permet de vérifier si pour l'enchère créée, l'objet est bien en vente, si le prix est plus petit grand que le prix de départ
-- ou si le prix est plus grand que le prix de la meilleure enchère pour cet objet
CREATE FUNCTION projet.enchereTrigger() RETURNS TRIGGER AS $$
DECLARE

BEGIN 
	IF
		'suspendu' = (SELECT etat_user
			      FROM projet.utilisateurs
			      WHERE login = NEW.acheteur) THEN
		RAISE 'Votre compte a été suspendu!';
	END IF;
	
	IF
		NEW.acheteur = (SELECT o.vendeur
				FROM projet.objets o
				WHERE o.id_objet = NEW.objet) THEN
		RAISE 'L acheteur ne peut pas être le vendeur!';

	ELSE
		IF
			'en vente' != (SELECT o.etat
				FROM projet.objets o
				WHERE o.id_objet = NEW.objet) THEN 
			RAISE 'Ce produit n est plus en vente!';
		END IF;
	END IF;
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
	
	RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trgger qui permet de faire la moyenne d'un utilisateur et de modifier son état et l'état de ses objets et/ou enchères
CREATE FUNCTION projet.creerEvalTrigger() RETURNS TRIGGER AS $$
DECLARE 
	nb_eval INTEGER;
	nb_eval_bis INTEGER;
	derniere_evaluation INTEGER;
	moyenne NUMERIC;
	tab_objet RECORD;
	
BEGIN 
	SELECT u.nb_eval_total
	FROM projet.utilisateurs u
	WHERE u.login = NEW.user_evaluer INTO nb_eval;

	SELECT u.eval_moyenne
	FROM projet.utilisateurs u
	WHERE u.login = NEW.user_evaluer INTO moyenne;

	SELECT u.derniere_eval
	FROM projet.utilisateurs u
	WHERE u.login = NEW.user_evaluer INTO derniere_evaluation;

	nb_eval_bis = nb_eval + 1;
	IF 
		(moyenne IS NULL) THEN
			moyenne = NEW.note_evaluation;
	ELSE 
		moyenne = moyenne * nb_eval;
		moyenne = moyenne + NEW.note_evaluation;
		moyenne = moyenne / nb_eval_bis;
	END IF;
		
	UPDATE projet.utilisateurs
	SET derniere_eval = NEW.note_evaluation, eval_moyenne = moyenne, nb_eval_total = nb_eval_bis
	WHERE login = NEW.user_evaluer;

	IF 
		(derniere_evaluation = 1 AND NEW.note_evaluation = 1) THEN
		UPDATE projet.utilisateurs
		SET etat_user = 'suspendu'
		WHERE login = NEW.user_evaluer;

		FOR tab_objet IN SELECT * FROM projet.objets o WHERE o.vendeur = NEW.user_evaluer LOOP
			UPDATE projet.encheres 
			SET etat = 'enchère annulée'
			WHERE objet = tab_objet.id_objet AND (etat != 'enchère remportée' AND etat != 'enchère perdue');
			IF
				 tab_objet.etat != 'vendu' THEN
					UPDATE projet.objets
					SET etat = 'annulé'
					WHERE vendeur = NEW.user_evaluer AND id_objet = tab_objet.id_objet;
			END IF;
		END LOOP;
		UPDATE projet.encheres 
		SET etat = 'enchère annulée'
		WHERE acheteur = NEW.user_evaluer;
	END IF;
	
	RETURN NEW;
END;
$$LANGUAGE plpgsql;

		----------------------------
		------APPEL TRIGGER---------
		----------------------------
		
CREATE TRIGGER trigger_enchere BEFORE INSERT ON projet.encheres 
	FOR EACH ROW EXECUTE PROCEDURE projet.enchereTrigger();


CREATE TRIGGER transTrigger BEFORE INSERT ON projet.transactions
	FOR EACH ROW EXECUTE PROCEDURE projet.transactionTrigger();

CREATE TRIGGER modObjTrigger BEFORE UPDATE ON projet.objets
	FOR EACH ROW EXECUTE PROCEDURE projet.modificationObjetTrigger();

CREATE TRIGGER modMoyenneTrigger AFTER INSERT ON projet.evaluations
	FOR EACH ROW EXECUTE PROCEDURE projet.creerEvalTrigger();
	
		----------------------------
		-----------TESTS------------
		----------------------------

SELECT projet.creerUtilisateur('A', 'A', 'A', 'A', 'A');
SELECT projet.creerUtilisateur('B', 'B', 'B', 'B', 'B');
SELECT projet.creerUtilisateur('C', 'C', 'C', 'C', 'C');

SELECT projet.creerObjet('Livres', 100, null, 'A');
SELECT projet.creerObjet('Jeux', 250, null, 'A');
SELECT projet.creerObjet('Canapés', 500, null, 'C');
SELECT projet.creerObjet('Ordi', 1000, null, 'A');

SELECT projet.creerEnchere(120, 1, 'B');
SELECT projet.creerEnchere(130, 1, 'C');
SELECT projet.creerEnchere(150, 1, 'B');
SELECT projet.creerEnchere(550, 2, 'C');
SELECT projet.creerEnchere(600, 2, 'B');
SELECT projet.creerEnchere(1100, 4, 'B');
SELECT projet.creerEnchere(550, 3, 'A');

SELECT projet.creerTransaction(3, 1);
SELECT projet.creerTransaction(5, 2);
SELECT projet.creerTransaction(6, 4);
SELECT projet.creerEvaluation(3, 'blabla', 1, 'A');
SELECT projet.creerEvaluation(2, 'bububu', 2, 'A');
SELECT projet.creerEvaluation(4, 'hahaha', 4, 'A');


	