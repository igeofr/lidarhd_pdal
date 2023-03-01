#!/bin/sh
# ------------------------------------------------------------------------------

# VARIABLES DATES
export DATE_YM=$(date "+%Y%m")
export DATE_YMD=$(date "+%Y%m%d")

# LECTURE DU FICHIER DE CONFIGURATION
. "`dirname "$0"`/config.env"

# REPERTOIRE DE TRAVAIL
cd $REPER
echo $REPER

# Installation de p7zip : sudo apt install p7zip
#7z x $REPER"/data_in/*.7z" -o$REPER'/data_tmp/unzip'

rm -r -f $REPER'/data_tmp/colorisation/'*
rm -r -f $REPER'/data_tmp/filter/'*
rm -r -f $REPER'/data_tmp/ground/'*
rm -r -f $REPER'/data_tmp/no_ground/'*

for file in "$REPER/data_in/"*.7z ; do    # full path to each txt
    echo "$file"
    filename="${file##*/}"     # file name without path
    echo "${filename}"
    base="${filename%.7z}"    # file name without path extension
    echo "${base}"

   ####################################################################
   rm -r -f $REPER'/data_tmp/un7z/'*
   7z x "$REPER/data_in/$base.7z" -o$REPER'/data_tmp/un7z'
   ####################################################################
   for file_lidar in $REPER"/data_tmp/un7z/${base}/"*.laz; do

        filename_lidar="${file_lidar##*/}"   # file name without path
        echo "${filename_lidar}"
        base_lidar=${filename_lidar%.laz}    # file name without path or extension
        echo "${base_lidar}"

        base_lidar_x=$( echo $base_lidar | cut -c13-15)
        echo $base_lidar_x
        base_lidar_y=$( echo $base_lidar | cut -c17-20)
        echo $base_lidar_y

        ref_ortho_x=$(awk -v n=$base_lidar_x -v d=5 'BEGIN{print int((n-2+d/2)/d) * d}')
        ref_ortho_y=$(awk -v n=$base_lidar_y -v d=5 'BEGIN{print int((n+2+d/2)/d) * d}')

        #ref_lidar_x_gauche=$(awk -v n=$base_lidar_x 'BEGIN{print int(n-1)}')
        ref_lidar_x_droite=$(awk -v n=$base_lidar_x 'BEGIN{print int(n+1)}')

        #ref_lidar_y_haut=$(awk -v n=$base_lidar_y 'BEGIN{print int(n+1)}')
        ref_lidar_y_bas=$(awk -v n=$base_lidar_y 'BEGIN{print int(n-1)}')

        echo $ref_ortho_x
        echo $ref_ortho_y

        #echo $ref_lidar_x_gauche
        echo $ref_lidar_x_droite
        #echo $ref_lidar_y_haut
        echo $ref_lidar_y_bas

        # Colorisation de la dalle
        if [ -d $REPER'/data_tmp/colorisation/'${base} ]; then
          echo 'Le répertoire colorisation existe'
        else
          mkdir $REPER'/data_tmp/colorisation/'${base}
        fi
        pdal pipeline 1_colorize.json --readers.las.filename=$REPER'/data_tmp/un7z/'${base}'/'$filename_lidar \
                                      --filters.colorization.raster="/home/utilisateur/Documents/traitement_LIDAR/data_ortho/34-2021-0"$ref_ortho_x"-"$ref_ortho_y"-LA93-0M20-E080.jp2" \
                                      --writers.las.filename=$REPER'/data_tmp/colorisation/'${base}'/'$base_lidar'_color.laz'

        ref_xmax=$(expr $base_lidar_x + 2)
        ref_ymin=$(expr $base_lidar_x - 2)

        ogr2ogr -f 'ESRI Shapefile' -progress -skipfailures -overwrite -nlt POLYGON -clipsrc $base_lidar_x'000' $ref_lidar_y_bas'000' $ref_lidar_x_droite'000' $base_lidar_y'000' batiments_clip.shp BATIMENT.shp
        ogr2ogr \
                -f "ESRI Shapefile" \
                -progress -skipfailures -overwrite \
                -dialect SQLITE \
                -nlt POLYGON \
                -sql "SELECT ST_Union(st_buffer(ST_MakeValid(geometry),0)) as geometry, 7 AS classif FROM batiments_clip WHERE st_IsValid(st_buffer(ST_MakeValid(geometry),0))" \
                batiments_classif.shp batiments_clip.shp


        # Filtre des données
         if [ -d $REPER'/data_tmp/filter/'${base} ]; then
           echo 'Le répertoire filter existe'
         else
          mkdir $REPER'/data_tmp/filter/'${base}
        fi
        pdal pipeline 2_pipeline.json --verbose 4 --readers.las.filename=$REPER'/data_tmp/colorisation/'${base}'/'${filename_lidar%%.*}'_color.laz' \
                                      --writers.las.filename=$REPER'/data_tmp/filter/'${base}'/'$base_lidar'_filter.laz'

        # Extraction des données du sol
        if [ -d $REPER'/data_tmp/ground/'${base} ]; then
          echo 'Le répertoire ground existe'
        else
          mkdir $REPER'/data_tmp/ground/'${base}
        fi
        pdal pipeline 3_ground.json --verbose 4 --readers.las.filename=$REPER'/data_tmp/filter/'${base}'/'${filename_lidar%%.*}'_filter.laz' \
                                    --writers.las.filename=$REPER'/data_tmp/ground/'${base}'/'$base_lidar'_ground.laz'

        # Extraction des données du sur sol
        if [ -d $REPER'/data_tmp/no_ground/'${base} ]; then
         echo 'Le répertoire no_ground existe'
        else
         mkdir $REPER'/data_tmp/no_ground/'${base}
        fi
        pdal pipeline 4_non_ground.json --readers.las.filename=$REPER'/data_tmp/filter/'${base}'/'${filename_lidar%%.*}'_filter.laz' \
                                        --writers.las.filename=$REPER'/data_tmp/no_ground/'${base}'/'$base_lidar'_no_ground.laz'

   done

   list_ground=$(ls $REPER'/data_tmp/ground/'${base}'/'*'.laz')
   #echo $list_ground
   pdal merge $list_ground $REPER'/data_tmp/ground/'${base}'_ground.laz'

   list_no_ground=$(ls $REPER'/data_tmp/no_ground/'${base}'/'*'.laz')
   #echo $list_no_ground
   pdal merge $list_no_ground $REPER'/data_tmp/no_ground/'${base}'_no_ground.laz'
   
   # Export du sol en raster
   pdal pipeline 5_ground_raster.json --readers.las.filename=$REPER'/data_tmp/ground/'${base}'_ground.laz' \
                            --writers.gdal.filename=$REPER'/data_tmp/ground_raster/'${base}'_ground_raster.tif'

done
