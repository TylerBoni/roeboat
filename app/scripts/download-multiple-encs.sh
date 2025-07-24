#!/bin/bash

# Download and convert multiple ENC data from NOAA
OUTPUT_DIR="public/enc-data"
TEMP_BASE_DIR="temp-enc"

# Create directories
mkdir -p $OUTPUT_DIR

echo "Downloading multiple ENC charts from NOAA..."

# List of ENC charts to download (you can add more)
ENC_CHARTS=(
    "US5WA3BB"  # Portland, Oregon
    "US5WA3BC"  # Columbia River
    "US5WA3BD"  # Willamette River
    "US5WA3BE"  # Puget Sound
    "US5WA3BF"  # Seattle
    "US5WA3BG"  # Tacoma
    "US5WA3BH"  # Everett
    "US5WA3BI"  # Bellingham
    "US5WA3BJ"  # Olympia
    "US5WA3BK"  # Port Angeles
    "US5WA3BL"  # Port Townsend
    "US5WA3BM"  # Anacortes
    "US5WA3BN"  # Friday Harbor
    "US5WA3BO"  # Roche Harbor
    "US5WA3BP"  # Eastsound
    "US5WA3BQ"  # Deer Harbor
    "US5WA3BR"  # West Sound
    "US5WA3BS"  # Shaw Island
    "US5WA3BT"  # Lopez Island
    "US5WA3BU"  # San Juan Island
)

for chart in "${ENC_CHARTS[@]}"; do
    echo "Processing chart: $chart"
    
    # Create unique temp directory for this chart
    TEMP_DIR="${TEMP_BASE_DIR}_${chart}"
    mkdir -p $TEMP_DIR
    
    # Download the chart
    ENC_URL="https://charts.noaa.gov/ENCs/${chart}.zip"
    echo "Downloading $chart..."
    curl -L -o $TEMP_DIR/${chart}.zip "$ENC_URL"
    
    if [ -f $TEMP_DIR/${chart}.zip ]; then
        echo "Extracting $chart..."
        unzip -q $TEMP_DIR/${chart}.zip -d $TEMP_DIR/
        
        # Find the .000 file (S-57 format)
        ENC_FILE=$(find $TEMP_DIR -name "${chart}.000" | head -n 1)
        
        if [ -n "$ENC_FILE" ]; then
            echo "Converting $chart to GeoJSON..."
            
            # First, let's see what layers are available
            echo "Available layers for $chart:"
            ogrinfo $ENC_FILE | grep -E "^[0-9]+:" | head -20
            
            # Convert detailed bathymetry layers
            echo "Converting DEPARE (depth areas)..."
            ogr2ogr -f "GeoJSON" \
                    -t_srs "EPSG:4326" \
                    -skipfailures \
                    $OUTPUT_DIR/${chart}_depare.geojson \
                    $ENC_FILE \
                    DEPARE
            
            echo "Converting DEPCNT (depth contours)..."
            ogr2ogr -f "GeoJSON" \
                    -t_srs "EPSG:4326" \
                    -skipfailures \
                    $OUTPUT_DIR/${chart}_depcnt.geojson \
                    $ENC_FILE \
                    DEPCNT
            
            echo "Converting SOUNDG (soundings)..."
            ogr2ogr -f "GeoJSON" \
                    -t_srs "EPSG:4326" \
                    -skipfailures \
                    $OUTPUT_DIR/${chart}_soundg.geojson \
                    $ENC_FILE \
                    SOUNDG
            
            echo "Converting LNDARE (land areas)..."
            ogr2ogr -f "GeoJSON" \
                    -t_srs "EPSG:4326" \
                    -skipfailures \
                    $OUTPUT_DIR/${chart}_lndare.geojson \
                    $ENC_FILE \
                    LNDARE
            
            echo "Converting LIGHTS (lights)..."
            ogr2ogr -f "GeoJSON" \
                    -t_srs "EPSG:4326" \
                    -skipfailures \
                    $OUTPUT_DIR/${chart}_lights.geojson \
                    $ENC_FILE \
                    LIGHTS
            
            echo "Converting NAVLNE (navigation lines)..."
            ogr2ogr -f "GeoJSON" \
                    -t_srs "EPSG:4326" \
                    -skipfailures \
                    $OUTPUT_DIR/${chart}_navlne.geojson \
                    $ENC_FILE \
                    NAVLNE
            
            echo "Converting DRGARE (dredged areas)..."
            ogr2ogr -f "GeoJSON" \
                    -t_srs "EPSG:4326" \
                    -skipfailures \
                    $OUTPUT_DIR/${chart}_drgare.geojson \
                    $ENC_FILE \
                    DRGARE
            
            echo "Converting OBSTRN (obstructions)..."
            ogr2ogr -f "GeoJSON" \
                    -t_srs "EPSG:4326" \
                    -skipfailures \
                    $OUTPUT_DIR/${chart}_obstrn.geojson \
                    $ENC_FILE \
                    OBSTRN
            
            echo "Converting BRIDGE (bridges)..."
            ogr2ogr -f "GeoJSON" \
                    -t_srs "EPSG:4326" \
                    -skipfailures \
                    $OUTPUT_DIR/${chart}_bridge.geojson \
                    $ENC_FILE \
                    BRIDGE
            
            echo "Converting PONTON (pontoon bridges)..."
            ogr2ogr -f "GeoJSON" \
                    -t_srs "EPSG:4326" \
                    -skipfailures \
                    $OUTPUT_DIR/${chart}_ponton.geojson \
                    $ENC_FILE \
                    PONTON
            
            echo "Converting BCNSPP (beacons)..."
            ogr2ogr -f "GeoJSON" \
                    -t_srs "EPSG:4326" \
                    -skipfailures \
                    $OUTPUT_DIR/${chart}_bcnsp.geojson \
                    $ENC_FILE \
                    BCNSPP
            
            echo "Converting BOYLAT (lateral buoys)..."
            ogr2ogr -f "GeoJSON" \
                    -t_srs "EPSG:4326" \
                    -skipfailures \
                    $OUTPUT_DIR/${chart}_boylat.geojson \
                    $ENC_FILE \
                    BOYLAT
            
            echo "Converting DAYMAR (daymarks)..."
            ogr2ogr -f "GeoJSON" \
                    -t_srs "EPSG:4326" \
                    -skipfailures \
                    $OUTPUT_DIR/${chart}_daymar.geojson \
                    $ENC_FILE \
                    DAYMAR
            
            echo "Converting DISMAR (distance marks)..."
            ogr2ogr -f "GeoJSON" \
                    -t_srs "EPSG:4326" \
                    -skipfailures \
                    $OUTPUT_DIR/${chart}_dismar.geojson \
                    $ENC_FILE \
                    DISMAR
            
            echo "Converting RDOSTA (radio stations)..."
            ogr2ogr -f "GeoJSON" \
                    -t_srs "EPSG:4326" \
                    -skipfailures \
                    $OUTPUT_DIR/${chart}_rdosta.geojson \
                    $ENC_FILE \
                    RDOSTA
            
            echo "Converting PILPNT (pilot points)..."
            ogr2ogr -f "GeoJSON" \
                    -t_srs "EPSG:4326" \
                    -skipfailures \
                    $OUTPUT_DIR/${chart}_pilpnt.geojson \
                    $ENC_FILE \
                    PILPNT
            
            echo "Converting PIPSOL (pilot services)..."
            ogr2ogr -f "GeoJSON" \
                    -t_srs "EPSG:4326" \
                    -skipfailures \
                    $OUTPUT_DIR/${chart}_pipsol.geojson \
                    $ENC_FILE \
                    PIPSOL
            
            echo "Converting RIVERS (rivers)..."
            ogr2ogr -f "GeoJSON" \
                    -t_srs "EPSG:4326" \
                    -skipfailures \
                    $OUTPUT_DIR/${chart}_rivers.geojson \
                    $ENC_FILE \
                    RIVERS
            
            echo "Converting COALNE (coastline)..."
            ogr2ogr -f "GeoJSON" \
                    -t_srs "EPSG:4326" \
                    -skipfailures \
                    $OUTPUT_DIR/${chart}_coalne.geojson \
                    $ENC_FILE \
                    COALNE
            
            echo "Converting DYKCON (dikes)..."
            ogr2ogr -f "GeoJSON" \
                    -t_srs "EPSG:4326" \
                    -skipfailures \
                    $OUTPUT_DIR/${chart}_dykcon.geojson \
                    $ENC_FILE \
                    DYKCON
            
            echo "Converting RECTRC (recommended tracks)..."
            ogr2ogr -f "GeoJSON" \
                    -t_srs "EPSG:4326" \
                    -skipfailures \
                    $OUTPUT_DIR/${chart}_rectrc.geojson \
                    $ENC_FILE \
                    RECTRC
            
            echo "Converting FAIRWY (fairways)..."
            ogr2ogr -f "GeoJSON" \
                    -t_srs "EPSG:4326" \
                    -skipfailures \
                    $OUTPUT_DIR/${chart}_fairwy.geojson \
                    $ENC_FILE \
                    FAIRWY
            
            echo "Converting LAKARE (lake areas)..."
            ogr2ogr -f "GeoJSON" \
                    -t_srs "EPSG:4326" \
                    -skipfailures \
                    $OUTPUT_DIR/${chart}_lakare.geojson \
                    $ENC_FILE \
                    LAKARE
            
            echo "Converting SEAARE (sea areas)..."
            ogr2ogr -f "GeoJSON" \
                    -t_srs "EPSG:4326" \
                    -skipfailures \
                    $OUTPUT_DIR/${chart}_seaare.geojson \
                    $ENC_FILE \
                    SEAARE
            
            echo "Converting SBDARE (seabed areas)..."
            ogr2ogr -f "GeoJSON" \
                    -t_srs "EPSG:4326" \
                    -skipfailures \
                    $OUTPUT_DIR/${chart}_sbdare.geojson \
                    $ENC_FILE \
                    SBDARE
            
            echo "Converting SLCONS (shoreline construction)..."
            ogr2ogr -f "GeoJSON" \
                    -t_srs "EPSG:4326" \
                    -skipfailures \
                    $OUTPUT_DIR/${chart}_slcons.geojson \
                    $ENC_FILE \
                    SLCONS
            
            echo "Converting SLOTOP (shoreline topography)..."
            ogr2ogr -f "GeoJSON" \
                    -t_srs "EPSG:4326" \
                    -skipfailures \
                    $OUTPUT_DIR/${chart}_slotop.geojson \
                    $ENC_FILE \
                    SLOTOP
            
            echo "Completed processing $chart"
        else
            echo "No .000 file found for $chart"
        fi
    else
        echo "Failed to download $chart"
    fi
    
    # Clean up this chart's temp directory
    rm -rf $TEMP_DIR
done

echo "Multiple ENC charts processing complete!"
echo "Available charts:"
ls -la $OUTPUT_DIR/*.geojson | head -30 