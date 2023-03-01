## Données [Lidar HD](https://geoservices.ign.fr/lidarhd) passées par [pdal](https://pdal.io)

Extraction du sol et du sur sol depuis les données du programme LidarHD de l'IGN.


### Création des répertoires

1. `data_in` : Contiendra les fichiers 7zip livrés par l'IGN
2. `data_ortho` : Contiendra les tuiles jp2 de l'IGN
3. `data_tmp` : Contiendra les fichiers temporaires dans les sous dossiers suivants
    - `colorisation`
    - `filter`
    - `ground`
    - `no_ground`
    - `ground_raster`
    - `un7z`
4. `data_out` : Contiendra les fichiers en sortie (Pas utilisé pour le moment, besoin en sortie pas complètement défini)

### Exécution du script

1. Paramétrer le fichier de config
2. Adapter si besoin les différents fichiers json utilisés par pdal (configuration du traitement)
3. Lancer le script `LIDAR.sh`
