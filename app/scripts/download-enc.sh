#!/bin/bash

# Download and convert ENC data from NOAA
ENC_URL="https://charts.noaa.gov/ENCs/US5WA3BB.zip"
OUTPUT_DIR="public/enc-data"
TEMP_DIR="temp-enc"

# Create directories
mkdir -p $OUTPUT_DIR
mkdir -p $TEMP_DIR

echo "Downloading ENC data from NOAA..."
curl -L -o $TEMP_DIR/enc.zip "$ENC_URL"

echo "Extracting ENC data..."
unzip -q $TEMP_DIR/enc.zip -d $TEMP_DIR/

echo "Converting S-57 to GeoJSON..."
# Find the .000 file (S-57 format)
ENC_FILE=$(find $TEMP_DIR -name "*.000" | head -n 1)

if [ -n "$ENC_FILE" ]; then
    echo "Found ENC file: $ENC_FILE"
    
    # Convert individual important layers
    echo "Converting DEPARE (depth areas)..."
    ogr2ogr -f "GeoJSON" \
            -t_srs "EPSG:4326" \
            -skipfailures \
            $OUTPUT_DIR/depare.geojson \
            $ENC_FILE \
            DEPARE
    
    echo "Converting LNDARE (land areas)..."
    ogr2ogr -f "GeoJSON" \
            -t_srs "EPSG:4326" \
            -skipfailures \
            $OUTPUT_DIR/lndare.geojson \
            $ENC_FILE \
            LNDARE
    
    echo "Converting LIGHTS (lights)..."
    ogr2ogr -f "GeoJSON" \
            -t_srs "EPSG:4326" \
            -skipfailures \
            $OUTPUT_DIR/lights.geojson \
            $ENC_FILE \
            LIGHTS
    
    echo "Converting NAVLNE (navigation lines)..."
    ogr2ogr -f "GeoJSON" \
            -t_srs "EPSG:4326" \
            -skipfailures \
            $OUTPUT_DIR/navlne.geojson \
            $ENC_FILE \
            NAVLNE
    
    echo "Converting DEPCNT (depth contours)..."
    ogr2ogr -f "GeoJSON" \
            -t_srs "EPSG:4326" \
            -skipfailures \
            $OUTPUT_DIR/depcnt.geojson \
            $ENC_FILE \
            DEPCNT
    
    echo "Conversion complete!"
else
    echo "No .000 file found in the downloaded data"
    exit 1
fi

# Clean up
rm -rf $TEMP_DIR

echo "ENC data processing complete!" 