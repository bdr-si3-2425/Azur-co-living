# Azur Co-Living  

## 🏡 Best Co-Living Agency Based at Polytech Nice-Sophia  

### 📌 Installation & Configuration  

1. **Base de données**  
   - La base de données est construite à partir du fichier `table_creation.sql`.  
   - Pour la remplir avec les jeux de tests utilisés, exécutez le script Python situé dans `./fill/script`.  

2. **Configuration de la connexion**  
   - Modifiez les paramètres de connexion à la base de données locale avant l'exécution.  

3. **Gestion des données**  
   - En cas d'ajout de nouvelles valeurs, exécutez `reset.sql` pour éviter les erreurs de duplication.  

### 📦 Dépendances  

Assurez-vous d'installer les bibliothèques nécessaires avant l'exécution :  

```bash
pip install psycopg2
pip install pandas
