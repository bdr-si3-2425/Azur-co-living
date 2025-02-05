import psycopg2
import pandas as pd
import os

#connection AUTH
def connect_db():
    return psycopg2.connect(
        dbname="pull", #change it
        user="postgres",
        password="admin", #change it
        host="localhost",
        port="5432"
    )

#verify if the file is correctly
def insert_data_from_csv(cursor, table_name, csv_file):
    if not os.path.exists(csv_file):
        print(f"Erreur : Le fichier {csv_file} n'existe pas.")
        return
    
    try:
        df = pd.read_csv(csv_file)
    except Exception as e:
        print(f"Erreur lors de la lecture du fichier {csv_file} : {e}")
        return
    
    if df.empty:
        print(f"Avertissement : Le fichier {csv_file} est vide.")
        return
    
    cols = ", ".join(df.columns)
    placeholders = ", ".join(["%s"] * len(df.columns))
    query = f"INSERT INTO {table_name} ({cols}) VALUES ({placeholders})"
    
    try:
        for _, row in df.iterrows():
            cursor.execute(query, tuple(row))
    except Exception as e:
        print(f"Erreur lors de l'insertion des données dans {table_name} : {e}")

def main():
    connection = connect_db()
    cursor = connection.cursor()
    tables = {
        "Type_logement": "type_logement.csv",
        "Logement": "logement.csv",
        "Equipement": "equipement.csv",
        "Chambre": "chambre.csv",
        "Profil": "profil.csv",
        "Resident": "resident.csv",
        "Reservation": "reservation.csv",
        "Type_intervention": "type_intervention.csv",
        "Intervention": "intervention.csv",
        "Conflit": "conflit.csv",
        "Resident_conflicts": "resident_conflicts.csv",
        "Evenement": "evenement.csv",
        "Logement_intervention": "logement_intervention.csv",
        "Participation": "participation.csv",
        "Note": "note.csv",
    }
    
    try:
        for table, csv_file in tables.items():
            print(f"Insertion des données dans {table} depuis {csv_file}...")
            insert_data_from_csv(cursor, table, csv_file)
            connection.commit()
        print("Importation terminée avec succès !")
    except Exception as e:
        print(f"Erreur : {e}")
        connection.rollback()
    finally:
        cursor.close()
        connection.close()

if __name__ == "__main__":
    main()
