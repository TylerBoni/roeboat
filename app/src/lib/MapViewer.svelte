<script lang="ts">
  import { onMount } from 'svelte';
  import Map from 'ol/Map';
  import View from 'ol/View';
  import TileLayer from 'ol/layer/Tile';
  import VectorLayer from 'ol/layer/Vector';
  import VectorSource from 'ol/source/Vector';
  import XYZ from 'ol/source/XYZ';
  import { fromLonLat, transform } from 'ol/proj';
  import GeoJSON from 'ol/format/GeoJSON';
  import { Fill, Stroke, Style, Circle, Text } from 'ol/style';
  import { defaults as defaultControls } from 'ol/control';
  import Feature from 'ol/Feature';
  import Point from 'ol/geom/Point';
  import { Geolocation, type Position, type PermissionStatus } from '@capacitor/geolocation'

  let mapElement: HTMLElement;
  let map: Map | undefined;
  let currentDepth: string = 'No depth data';
  let crosshairElement: HTMLElement;
  let isLegendExpanded = false;
  let userLocationLayer: VectorLayer<VectorSource>;
  let watchId: any; // Using any to handle both web number and Capacitor string IDs

  // Chart definitions with their center coordinates
  const charts = [
    { id: 'US5WA3BB', name: 'Portland, Oregon', center: [-122.5319122, 45.5873294] },
    { id: 'US5WA3BC', name: 'Columbia River', center: [-123.0, 46.0] },
    { id: 'US5WA3BD', name: 'Willamette River', center: [-122.7, 45.5] },
    { id: 'US5WA3BE', name: 'Puget Sound', center: [-122.5, 47.5] },
    { id: 'US5WA3BF', name: 'Seattle', center: [-122.3, 47.6] },
    { id: 'US5WA3BG', name: 'Tacoma', center: [-122.4, 47.2] },
    { id: 'US5WA3BH', name: 'Everett', center: [-122.2, 47.9] },
    { id: 'US5WA3BI', name: 'Bellingham', center: [-122.5, 48.7] },
    { id: 'US5WA3BJ', name: 'Olympia', center: [-122.9, 47.0] },
    { id: 'US5WA3BK', name: 'Port Angeles', center: [-123.4, 48.1] },
    { id: 'US5WA3BL', name: 'Port Townsend', center: [-122.8, 48.1] },
    { id: 'US5WA3BM', name: 'Anacortes', center: [-122.6, 48.5] },
    { id: 'US5WA3BN', name: 'Friday Harbor', center: [-123.0, 48.5] },
    { id: 'US5WA3BO', name: 'Roche Harbor', center: [-123.1, 48.6] },
    { id: 'US5WA3BP', name: 'Eastsound', center: [-122.9, 48.7] },
    { id: 'US5WA3BQ', name: 'Deer Harbor', center: [-123.0, 48.6] },
    { id: 'US5WA3BR', name: 'West Sound', center: [-122.9, 48.6] },
    { id: 'US5WA3BS', name: 'Shaw Island', center: [-122.9, 48.6] },
    { id: 'US5WA3BT', name: 'Lopez Island', center: [-122.9, 48.5] },
    { id: 'US5WA3BU', name: 'San Juan Island', center: [-123.0, 48.5] }
  ];

  // Enhanced depth styling with sand-to-blue color scheme (shallow to deep)
  const createDepthStyle = (feature: any) => {
    // Check both DRVAL1 and DRVAL2 for depth information
    let depthMeters = feature.get('DRVAL1');
    if (depthMeters === null || depthMeters === undefined) {
      depthMeters = feature.get('DRVAL2');
      // Only use 0 if both DRVAL1 and DRVAL2 are null/undefined
      if (depthMeters === null || depthMeters === undefined) {
        depthMeters = 0;
      }
    }
    
    const depthFeet = Math.max(0, depthMeters * 3.28084); // Convert meters to feet, ensure non-negative
    let color = '#BC8F8F'; // Default to rosy brown for very shallow/danger
    
    // Debug depth values
    console.log('Feature depth:', {
      meters: depthMeters,
      feet: depthFeet,
      drval1: feature.get('DRVAL1'),
      drval2: feature.get('DRVAL2')
    });
    
    // Sand-to-blue color scheme (shallow = sand, deep = dark blue)
    // Using strict comparison for depth ranges
    if (depthFeet >= 200) {
      color = '#000033'; // Navy blue (>200ft)
    } else if (depthFeet >= 150) {
      color = '#000066'; // Very dark blue (150-200ft)
    } else if (depthFeet >= 100) {
      color = '#000099'; // Dark blue (100-150ft)
    } else if (depthFeet >= 75) {
      color = '#0000CC'; // Medium dark blue (75-100ft)
    } else if (depthFeet >= 50) {
      color = '#0066CC'; // Steel blue (50-75ft)
    } else if (depthFeet >= 40) {
      color = '#0099FF'; // Medium blue (40-50ft)
    } else if (depthFeet >= 30) {
      color = '#66CCFF'; // Light blue (30-40ft)
    } else if (depthFeet >= 20) {
      color = '#99DDFF'; // Very light blue (20-30ft)
    } else if (depthFeet >= 15) {
      color = '#CCEEEE'; // Pale blue (15-20ft)
    } else if (depthFeet >= 10) {
      color = '#ECD9B6'; // Light sand (10-15ft)
    } else if (depthFeet >= 6) {
      color = '#DEB887'; // Burlywood (6-10ft)
    } else if (depthFeet >= 3) {
      color = '#D2B48C'; // Tan (3-6ft)
    } else if (depthFeet > 0) {
      color = '#BC8F8F'; // Rosy brown (0-3ft) - Danger zone
    } else {
      // Exactly 0 or negative depths
      color = '#BC8F8F'; // Rosy brown for danger zone
    }
    
    // Debug final color assignment
    console.log('Assigned color:', { depthFeet, color });
    
    return new Style({
      fill: new Fill({ color: color + 'DD' }), // More opaque
      stroke: new Stroke({ color: '#666666', width: 1 })
    });
  };

  const createLandStyle = () => {
    return new Style({
      fill: new Fill({ color: 'transparent' }),
      stroke: new Stroke({ color: '#666666', width: 1 })
    });
  };

  const createLightStyle = (feature: any) => {
    const color = feature.get('COLOUR') ? '#FFD700' : '#FFFFFF';
    return new Style({
      image: new Circle({
        radius: 6,
        fill: new Fill({ color }),
        stroke: new Stroke({ color: '#FF8C00', width: 2 })
      })
    });
  };

  const createNavigationLineStyle = () => {
    return new Style({
      stroke: new Stroke({
        color: '#FF0000',
        width: 2,
        lineDash: [10, 10] // Dashed line for navigation
      })
    });
  };

  // Enhanced depth contour styling with labels (in feet)
  const createDepthContourStyle = (feature: any) => {
    const depthMeters = feature.get('VALDCO') || 0;
    const depthFeet = depthMeters * 3.28084; // Convert meters to feet
    const width = depthFeet % 33 === 0 ? 1.5 : depthFeet % 16 === 0 ? 1 : 0.5; // Even thinner lines
    
    return new Style({
      stroke: new Stroke({
        color: 'rgba(100, 180, 255, 0.2)', // Much lighter blue with more transparency
        width: width
      }),
      text: new Text({
        text: Math.round(depthFeet).toString() + 'ft',
        font: '10px Arial',
        fill: new Fill({ color: 'rgba(100, 180, 255, 0.4)' }), // Lighter text color
        stroke: new Stroke({ color: '#FFFFFF', width: 2 }),
        offsetY: -10,
        placement: 'line'
      })
    });
  };

  // Create a separate layer for depth labels
  const createDepthLabelStyle = (feature: any) => {
    const depth = feature.get('DRVAL1') || feature.get('VALDCO') || 0;
    
    return new Style({
      text: new Text({
        text: `${depth}m`,
        font: 'bold 14px Arial',
        fill: new Fill({ color: '#0066CC' }),
        stroke: new Stroke({ color: '#FFFFFF', width: 3 }),
        placement: 'point'
      })
    });
  };

  // Sounding style - individual depth measurements (in feet)
  const createSoundingStyle = (feature: any) => {
    const depthMeters = feature.get('VALSOU') || 0;
    const depthFeet = depthMeters * 3.28084; // Convert meters to feet
    
    // Don't show soundings that are too shallow or zero
    if (depthFeet < 2) {
      return new Style(); // Empty style to hide very shallow soundings
    }
    
    const size = depthFeet > 66 ? 8 : depthFeet > 33 ? 6 : 4; // Size based on feet
    
    return new Style({
      image: new Circle({
        radius: size,
        fill: new Fill({ color: '#0066CC' }),
        stroke: new Stroke({ color: '#FFFFFF', width: 1 })
      }),
      text: new Text({
        text: Math.round(depthFeet).toString() + 'ft',
        font: 'bold 10px Arial',
        fill: new Fill({ color: '#0066CC' }),
        stroke: new Stroke({ color: '#FFFFFF', width: 2 }),
        offsetY: -15
      })
    });
  };

  // Dredged area style
  const createDredgedAreaStyle = () => {
    return new Style({
      fill: new Fill({ color: '#FFD700CC' }), // Gold with transparency
      stroke: new Stroke({ color: '#FF8C00', width: 2 })
    });
  };

  // Obstruction style
  const createObstructionStyle = () => {
    return new Style({
      fill: new Fill({ color: '#FF0000CC' }), // Red with transparency
      stroke: new Stroke({ color: '#8B0000', width: 2 })
    });
  };

  // Bridge style
  const createBridgeStyle = () => {
    return new Style({
      stroke: new Stroke({
        color: '#8B4513',
        width: 3
      })
    });
  };

  // Pontoon bridge style
  const createPontoonStyle = () => {
    return new Style({
      stroke: new Stroke({
        color: '#8B4513',
        width: 2,
        lineDash: [5, 5]
      })
    });
  };

  // Beacon style
  const createBeaconStyle = () => {
    return new Style({
      image: new Circle({
        radius: 4,
        fill: new Fill({ color: '#FFD700' }),
        stroke: new Stroke({ color: '#FF8C00', width: 2 })
      })
    });
  };

  // Buoy style
  const createBuoyStyle = () => {
    return new Style({
      image: new Circle({
        radius: 5,
        fill: new Fill({ color: '#FF0000' }),
        stroke: new Stroke({ color: '#8B0000', width: 2 })
      })
    });
  };

  // Daymark style
  const createDaymarkStyle = () => {
    return new Style({
      image: new Circle({
        radius: 4,
        fill: new Fill({ color: '#00FF00' }),
        stroke: new Stroke({ color: '#006400', width: 2 })
      })
    });
  };

  // Distance mark style
  const createDistanceMarkStyle = () => {
    return new Style({
      image: new Circle({
        radius: 3,
        fill: new Fill({ color: '#FFFFFF' }),
        stroke: new Stroke({ color: '#000000', width: 1 })
      })
    });
  };

  // Radio station style
  const createRadioStationStyle = () => {
    return new Style({
      image: new Circle({
        radius: 4,
        fill: new Fill({ color: '#FF69B4' }),
        stroke: new Stroke({ color: '#8B008B', width: 2 })
      })
    });
  };

  // Pilot point style
  const createPilotPointStyle = () => {
    return new Style({
      image: new Circle({
        radius: 4,
        fill: new Fill({ color: '#00CED1' }),
        stroke: new Stroke({ color: '#008B8B', width: 2 })
      })
    });
  };

  // Pilot service style
  const createPilotServiceStyle = () => {
    return new Style({
      fill: new Fill({ color: '#00CED1CC' }),
      stroke: new Stroke({ color: '#008B8B', width: 1 })
    });
  };

  // River style
  const createRiverStyle = () => {
    return new Style({
      stroke: new Stroke({
        color: '#0000FF',
        width: 2
      })
    });
  };

  // Coastline style
  const createCoastlineStyle = () => {
    return new Style({
      stroke: new Stroke({
        color: '#8B4513',
        width: 2
      })
    });
  };

  // Dike style
  const createDikeStyle = () => {
    return new Style({
      stroke: new Stroke({
        color: '#8B4513',
        width: 2,
        lineDash: [3, 3]
      })
    });
  };

  // Fairway style (marine channel)
  const createFairwayStyle = () => {
    return new Style({
      fill: undefined, // Remove fill completely
      stroke: new Stroke({
        color: '#FF0000',
        width: 2,
        lineDash: [10, 10] // Dashed line
      })
    });
  };

  // Recommended track style
  const createRecommendedTrackStyle = () => {
    return new Style({
      fill: undefined, // Remove fill completely
      stroke: new Stroke({
        color: '#FF0000',
        width: 2,
        lineDash: [5, 5] // Shorter dashed line
      })
    });
  };

  // Lake area style
  const createLakeAreaStyle = () => {
    return new Style({
      fill: new Fill({ color: '#87CEEBCC' }),
      stroke: new Stroke({ color: '#4682B4', width: 1 })
    });
  };

  // Sea area style
  const createSeaAreaStyle = () => {
    return new Style({
      fill: new Fill({ color: '#E6F3FFCC' }),
      stroke: new Stroke({ color: '#0066CC', width: 1 })
    });
  };

  // Seabed area style
  const createSeabedAreaStyle = () => {
    return new Style({
      fill: new Fill({ color: '#F5DEB3CC' }),
      stroke: new Stroke({ color: '#D2691E', width: 1 })
    });
  };

  // Shoreline construction style
  const createShorelineConstructionStyle = () => {
    return new Style({
      stroke: new Stroke({
        color: '#8B4513',
        width: 2
      })
    });
  };

  // Shoreline topography style
  const createShorelineTopographyStyle = () => {
    return new Style({
      stroke: new Stroke({
        color: '#8B4513',
        width: 1
      })
    });
  };

  function loadAllChartLayers() {
    if (!map) return;

    const layers = map.getLayers();

    // Load all available charts
    charts.forEach(chart => {
      // Create vector sources for each chart
      const depareSource = new VectorSource({
        url: `/enc-data/${chart.id}_depare.geojson`,
        format: new GeoJSON()
      });

      const lndareSource = new VectorSource({
        url: `/enc-data/${chart.id}_lndare.geojson`,
        format: new GeoJSON()
      });

      const lightsSource = new VectorSource({
        url: `/enc-data/${chart.id}_lights.geojson`,
        format: new GeoJSON()
      });

      const navlneSource = new VectorSource({
        url: `/enc-data/${chart.id}_navlne.geojson`,
        format: new GeoJSON()
      });

      const depcntSource = new VectorSource({
        url: `/enc-data/${chart.id}_depcnt.geojson`,
        format: new GeoJSON()
      });

      // Additional bathymetry layers
      const soundgSource = new VectorSource({
        url: `/enc-data/${chart.id}_soundg.geojson`,
        format: new GeoJSON()
      });

      const drgareSource = new VectorSource({
        url: `/enc-data/${chart.id}_drgare.geojson`,
        format: new GeoJSON()
      });

      const obstrnSource = new VectorSource({
        url: `/enc-data/${chart.id}_obstrn.geojson`,
        format: new GeoJSON()
      });

      const bridgeSource = new VectorSource({
        url: `/enc-data/${chart.id}_bridge.geojson`,
        format: new GeoJSON()
      });

      const pontonSource = new VectorSource({
        url: `/enc-data/${chart.id}_ponton.geojson`,
        format: new GeoJSON()
      });

      const bcnspSource = new VectorSource({
        url: `/enc-data/${chart.id}_bcnsp.geojson`,
        format: new GeoJSON()
      });

      const boylatSource = new VectorSource({
        url: `/enc-data/${chart.id}_boylat.geojson`,
        format: new GeoJSON()
      });

      const daymarSource = new VectorSource({
        url: `/enc-data/${chart.id}_daymar.geojson`,
        format: new GeoJSON()
      });

      const dismarSource = new VectorSource({
        url: `/enc-data/${chart.id}_dismar.geojson`,
        format: new GeoJSON()
      });

      const rdostaSource = new VectorSource({
        url: `/enc-data/${chart.id}_rdosta.geojson`,
        format: new GeoJSON()
      });

      const pilpntSource = new VectorSource({
        url: `/enc-data/${chart.id}_pilpnt.geojson`,
        format: new GeoJSON()
      });

      const pipsolSource = new VectorSource({
        url: `/enc-data/${chart.id}_pipsol.geojson`,
        format: new GeoJSON()
      });

      const riversSource = new VectorSource({
        url: `/enc-data/${chart.id}_rivers.geojson`,
        format: new GeoJSON()
      });

      const coalneSource = new VectorSource({
        url: `/enc-data/${chart.id}_coalne.geojson`,
        format: new GeoJSON()
      });

      const dykconSource = new VectorSource({
        url: `/enc-data/${chart.id}_dykcon.geojson`,
        format: new GeoJSON()
      });

      const rectrcSource = new VectorSource({
        url: `/enc-data/${chart.id}_rectrc.geojson`,
        format: new GeoJSON()
      });

      const fairwySource = new VectorSource({
        url: `/enc-data/${chart.id}_fairwy.geojson`,
        format: new GeoJSON()
      });

      const lakareSource = new VectorSource({
        url: `/enc-data/${chart.id}_lakare.geojson`,
        format: new GeoJSON()
      });

      const seaareSource = new VectorSource({
        url: `/enc-data/${chart.id}_seaare.geojson`,
        format: new GeoJSON()
      });

      const sbdareSource = new VectorSource({
        url: `/enc-data/${chart.id}_sbdare.geojson`,
        format: new GeoJSON()
      });

      const slconsSource = new VectorSource({
        url: `/enc-data/${chart.id}_slcons.geojson`,
        format: new GeoJSON()
      });

      const slotopSource = new VectorSource({
        url: `/enc-data/${chart.id}_slotop.geojson`,
        format: new GeoJSON()
      });

      // Add ENC layers for this chart with error handling
      const chartLayers = [
        new VectorLayer({
          source: depareSource,
          style: createDepthStyle,
          zIndex: 1,
          updateWhileAnimating: true,
          updateWhileInteracting: true,
          renderBuffer: 50,
          properties: { name: `enc_depare_${chart.id}`, type: 'depth_area' }
        }),
        new VectorLayer({
          source: lndareSource,
          style: createLandStyle,
          zIndex: 2,
          updateWhileAnimating: true,
          updateWhileInteracting: true,
          renderBuffer: 50,
          properties: { name: `enc_lndare_${chart.id}` }
        }),
        new VectorLayer({
          source: depcntSource,
          style: createDepthContourStyle,
          zIndex: 3,
          updateWhileAnimating: true,
          updateWhileInteracting: true,
          renderBuffer: 50,
          properties: { name: `enc_depcnt_${chart.id}`, type: 'depth_contour' }
        }),
        new VectorLayer({
          source: fairwySource,
          style: createFairwayStyle,
          zIndex: 4,
          updateWhileAnimating: true,
          updateWhileInteracting: true,
          renderBuffer: 50,
          properties: { name: `enc_fairwy_${chart.id}` }
        }),
        new VectorLayer({
          source: rectrcSource,
          style: createRecommendedTrackStyle,
          zIndex: 5,
          updateWhileAnimating: true,
          updateWhileInteracting: true,
          renderBuffer: 50,
          properties: { name: `enc_rectrc_${chart.id}` }
        }),
        new VectorLayer({
          source: navlneSource,
          style: createNavigationLineStyle,
          zIndex: 6,
          updateWhileAnimating: true,
          updateWhileInteracting: true,
          renderBuffer: 50,
          properties: { name: `enc_navlne_${chart.id}` }
        }),
        new VectorLayer({
          source: lightsSource,
          style: createLightStyle,
          zIndex: 7,
          updateWhileAnimating: true,
          updateWhileInteracting: true,
          renderBuffer: 50,
          properties: { name: `enc_lights_${chart.id}` }
        })
      ];

      // Add layers with error handling
      chartLayers.forEach(layer => {
        const source = layer.getSource();
        if (source) {
          source.on('featuresloaderror', () => {
            console.warn(`Failed to load data for ${chart.id}`);
          });
        }
        layers.push(layer);
      });
    });

    // Also load the existing single chart files as fallback
    const fallbackSources = [
      { url: '/enc-data/depare.geojson', name: 'enc_depare_fallback' },
      { url: '/enc-data/lndare.geojson', name: 'enc_lndare_fallback' },
      { url: '/enc-data/lights.geojson', name: 'enc_lights_fallback' },
      { url: '/enc-data/navlne.geojson', name: 'enc_navlne_fallback' },
      { url: '/enc-data/depcnt.geojson', name: 'enc_depcnt_fallback' }
    ];

    fallbackSources.forEach(({ url, name }) => {
      const source = new VectorSource({
        url: url,
        format: new GeoJSON()
      });

      const layer = new VectorLayer({
        source: source,
        style: name.includes('depare') ? createDepthStyle :
               name.includes('lndare') ? createLandStyle :
               name.includes('lights') ? createLightStyle :
               name.includes('navlne') ? createNavigationLineStyle :
               createDepthContourStyle,
        zIndex: 1,
        updateWhileAnimating: true,
        updateWhileInteracting: true,
        renderBuffer: 50,
        properties: { name: name }
      });

      layers.push(layer);
    });
  }

  // Function to get depth at a specific coordinate
  function getDepthAtCoordinate(coordinate: number[]) {
    if (!map) return { depth: 'No depth data', name: '' };
    
    const layers = map.getLayers();
    let minDepth = Infinity;
    let depthInfo = 'No depth data';
    let objectName = '';
    let foundDepth = false;
    
    // Process layers in reverse order (top to bottom) to match visual representation
    const vectorLayers = Array.from(layers.getArray()).reverse().filter(layer => 
      layer instanceof VectorLayer
    );

    // First pass: check for point measurements (soundings)
    vectorLayers.forEach(layer => {
      if (layer instanceof VectorLayer) {
        const layerProps = layer.getProperties();
        if (layerProps.type === 'sounding') {
          const source = layer.getSource();
          if (source) {
            const features = source.getFeatures();
            features.forEach((feature: any) => {
              const geometry = feature.getGeometry();
              if (geometry && geometry.getType() === 'Point') {
                const coord = geometry.getCoordinates();
                // Check if point is very close to crosshair (within 5 pixels)
                const pixel = map!.getPixelFromCoordinate(coord);
                const targetPixel = map!.getPixelFromCoordinate(coordinate);
                if (pixel && targetPixel) {
                  const dx = pixel[0] - targetPixel[0];
                  const dy = pixel[1] - targetPixel[1];
                  const distance = Math.sqrt(dx * dx + dy * dy);
                  if (distance < 5) {
                    const depth = feature.get('VALSOU');
                    if (depth !== undefined && depth < minDepth) {
                      minDepth = depth;
                      const depthFeet = depth * 3.28084;
                      depthInfo = `${Math.round(depthFeet)}ft`;
                      foundDepth = true;
                    }
                  }
                }
              }
            });
          }
        }
      }
    });

    // Second pass: check for areas if no point measurement found
    if (!foundDepth) {
      vectorLayers.forEach(layer => {
        if (layer instanceof VectorLayer) {
          const layerProps = layer.getProperties();
          if (layerProps.type === 'depth_area' || layerProps.type === 'dredged_area') {
            const source = layer.getSource();
            if (source) {
              const features = source.getFeatures();
              features.forEach((feature: any) => {
                const geometry = feature.getGeometry();
                if (geometry && geometry.intersectsCoordinate && geometry.intersectsCoordinate(coordinate)) {
                  // For depth areas, use DRVAL1 (minimum depth) for safety
                  const depth = feature.get('DRVAL1');
                  if (depth !== undefined && depth < minDepth) {
                    minDepth = depth;
                    const depthFeet = depth * 3.28084;
                    depthInfo = `${Math.round(depthFeet)}ft`;
                    foundDepth = true;
                  }
                }
              });
            }
          }
        }
      });
    }

    // Get object name from any intersecting feature
    vectorLayers.forEach(layer => {
      if (layer instanceof VectorLayer && !objectName) {
        const source = layer.getSource();
        if (source) {
          const features = source.getFeatures();
          features.forEach((feature: any) => {
            const geometry = feature.getGeometry();
            if (geometry && geometry.intersectsCoordinate && geometry.intersectsCoordinate(coordinate)) {
              const name = feature.get('OBJNAM') || feature.get('LNAM');
              if (name && !name.match(/^[0-9A-F]{16}$/) && 
                  !name.match(/^[0-9]+$/) && 
                  !name.includes('US5WA')) {
                objectName = name;
              }
            }
          });
        }
      }
    });
    
    return { depth: depthInfo, name: objectName };
  }

  // Function to update depth display when map moves
  function updateDepthDisplay() {
    if (!map) return;
    
    const center = map.getView().getCenter();
    if (center) {
      const { depth, name } = getDepthAtCoordinate(center);
      currentDepth = depth + (name ? ` - ${name}` : '');
    }
  }

  // Function to save map position to localStorage
  function saveMapPosition() {
    if (!map) return;
    
    const view = map.getView();
    const center = view.getCenter();
    const zoom = view.getZoom();
    
    if (center) {
      const position = {
        center: center,
        zoom: zoom,
        timestamp: Date.now()
      };
      localStorage.setItem('mapPosition', JSON.stringify(position));
    }
  }

  // Function to restore map position from localStorage
  function restoreMapPosition() {
    const saved = localStorage.getItem('mapPosition');
    if (saved) {
      try {
        const position = JSON.parse(saved);
        // Only restore if saved within last 24 hours
        if (Date.now() - position.timestamp < 24 * 60 * 60 * 1000) {
          return {
            center: position.center,
            zoom: position.zoom
          };
        }
      } catch (e) {
        console.warn('Failed to restore map position:', e);
      }
    }
    return null;
  }

  // Create a style for the user location marker
  const userLocationStyle = new Style({
    image: new Circle({
      radius: 8,
      fill: new Fill({ color: '#007AFF' }),
      stroke: new Stroke({
        color: '#FFFFFF',
        width: 2
      })
    })
  });

  // Create a source and layer for the user location
  const userLocationSource = new VectorSource();
  userLocationLayer = new VectorLayer({
    source: userLocationSource,
    style: userLocationStyle,
    zIndex: 1000 // Make sure it's above other layers
  });

  // Function to update user location on the map
  async function updateUserLocation(position: Position) {
    const { latitude, longitude } = position.coords;
    const coordinates = transform([longitude, latitude], 'EPSG:4326', 'EPSG:3857');
    
    // Create or update the location feature
    const locationFeature = new Feature({
      geometry: new Point(coordinates)
    });
    
    userLocationSource.clear();
    userLocationSource.addFeature(locationFeature);
  }

  // Helper to check if we're running in a browser
  const isWeb = typeof window !== 'undefined' && !window.hasOwnProperty('Capacitor');

  // Function to convert web position to Capacitor position format
  function webToCapacitorPosition(webPosition: GeolocationPosition): Position {
    return {
      coords: {
        latitude: webPosition.coords.latitude,
        longitude: webPosition.coords.longitude,
        accuracy: webPosition.coords.accuracy,
        altitude: webPosition.coords.altitude,
        altitudeAccuracy: webPosition.coords.altitudeAccuracy,
        heading: webPosition.coords.heading,
        speed: webPosition.coords.speed
      },
      timestamp: webPosition.timestamp
    };
  }

  // Function to start watching user location
  async function startLocationTracking() {
    try {
      if (isWeb) {
        // Web browser implementation
        if ('geolocation' in navigator) {
          // Request permission explicitly first
          const permission = await new Promise<GeolocationPosition>((resolve, reject) => {
            navigator.geolocation.getCurrentPosition(resolve, reject, {
              enableHighAccuracy: true,
              timeout: 10000,
              maximumAge: 0
            });
          });

          // If we got here, permission was granted and we have initial position
          updateUserLocation(webToCapacitorPosition(permission));

          // Now start watching
          const webWatchId = navigator.geolocation.watchPosition(
            (position) => {
              updateUserLocation(webToCapacitorPosition(position));
            },
            (error) => {
              console.error('Error watching location:', error);
            },
            { 
              enableHighAccuracy: true,
              timeout: 10000,
              maximumAge: 0
            }
          );
          
          watchId = webWatchId;
        } else {
          throw new Error('Geolocation is not supported by this browser');
        }
      } else {
        // Native implementation using Capacitor
        const permResult = await Geolocation.checkPermissions();
        if (permResult.location !== 'granted') {
          await Geolocation.requestPermissions();
        }

        // Get initial position
        const position = await Geolocation.getCurrentPosition();
        updateUserLocation(position);

        // Watch for position changes
        const callback = (position: Position | null, err?: any) => {
          if (err) {
            console.error('Error watching location:', err);
            return;
          }
          if (position) {
            updateUserLocation(position);
          }
        };

        watchId = await Geolocation.watchPosition(
          { enableHighAccuracy: true },
          callback
        );
      }
    } catch (error) {
      console.error('Error setting up location tracking:', error);
      throw error; // Re-throw to handle in the onMount
    }
  }

  // Function to stop watching user location
  async function stopLocationTracking() {
    if (watchId) {
      try {
        if (isWeb) {
          navigator.geolocation.clearWatch(watchId as number);
        } else {
          await Geolocation.clearWatch({ id: watchId as string });
        }
        watchId = null;
      } catch (error) {
        console.error('Error stopping location tracking:', error);
      }
    }
  }

  onMount(() => {
    // Ensure the container has proper dimensions
    setTimeout(() => {
      // Check if container has proper dimensions
      if (mapElement && mapElement.offsetWidth > 0 && mapElement.offsetHeight > 0) {
        // Try to restore saved position
        const savedPosition = restoreMapPosition();
        const initialCenter = savedPosition?.center || fromLonLat([-122.5, 47.5]);
        const initialZoom = savedPosition?.zoom || 10;
        
        map = new Map({
          target: mapElement,
          controls: defaultControls({
            zoom: true,
            rotate: true,
            attribution: true
          }),
          layers: [
            // Base layer - OpenStreetMap
            new TileLayer({
              source: new XYZ({
                url: 'https://{a-c}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                attributions: '© OpenStreetMap contributors'
              }),
              opacity: 1
            }),
            // Add user location layer
            userLocationLayer
          ],
          view: new View({
            center: initialCenter,
            zoom: initialZoom,
            minZoom: 2,
            maxZoom: 18
          })
        });

        // Load all charts
        loadAllChartLayers();

        // Add event listeners for depth updates
        const view = map.getView();
        view.on('change:center', () => {
          updateDepthDisplay();
          saveMapPosition();
        });
        view.on('change:resolution', () => {
          updateDepthDisplay();
          saveMapPosition();
        });
        
        // Initial depth update
        updateDepthDisplay();

        // Start location tracking immediately after map initialization
        startLocationTracking().catch(error => {
          console.error('Failed to start location tracking:', error);
        });
      } else {
        console.error('Map container has no dimensions:', mapElement?.offsetWidth, mapElement?.offsetHeight);
      }
    }, 100);

    return () => {
      if (map) {
        stopLocationTracking().catch(console.error);
        map.setTarget(undefined);
        map = undefined;
      }
    };
  });
</script>

<div class="map-wrapper">
  <div class="map-container" bind:this={mapElement}></div>
  
  <!-- Crosshair overlay -->
  <div class="crosshair" bind:this={crosshairElement}>
    <div class="crosshair-horizontal"></div>
    <div class="crosshair-vertical"></div>
  </div>
  
  <!-- Depth display -->
  <div class="depth-display">
    <div class="depth-compact">
      <span class="depth-label">Info:</span>
      <span class="depth-value">{currentDepth}</span>
    </div>
  </div>
  
  <div class="legend" class:collapsed={!isLegendExpanded}>
    <div class="legend-header" on:click={() => isLegendExpanded = !isLegendExpanded}>
      <h3>Legend</h3>
      <button class="legend-toggle" aria-label="Toggle legend">
        {isLegendExpanded ? '−' : '+'}
      </button>
    </div>
    
    <div class="legend-content">
      <div class="legend-section">
        <h4>Depth Areas</h4>
        <div class="legend-item">
          <div class="legend-color" style="background-color: #BC8F8F;"></div>
          <span>0-3ft (Danger - Very Shallow)</span>
        </div>
        <div class="legend-item">
          <div class="legend-color" style="background-color: #D2B48C;"></div>
          <span>3-6ft (Caution - Shallow)</span>
        </div>
        <div class="legend-item">
          <div class="legend-color" style="background-color: #DEB887;"></div>
          <span>6-10ft (Shallow)</span>
        </div>
        <div class="legend-item">
          <div class="legend-color" style="background-color: #ECD9B6;"></div>
          <span>10-15ft (Light Sand)</span>
        </div>
        <div class="legend-item">
          <div class="legend-color" style="background-color: #CCEEEE;"></div>
          <span>15-20ft (Transition)</span>
        </div>
        <div class="legend-item">
          <div class="legend-color" style="background-color: #99DDFF;"></div>
          <span>20-30ft (Light Blue)</span>
        </div>
        <div class="legend-item">
          <div class="legend-color" style="background-color: #66CCFF;"></div>
          <span>30-40ft (Medium)</span>
        </div>
        <div class="legend-item">
          <div class="legend-color" style="background-color: #0099FF;"></div>
          <span>40-50ft (Deep)</span>
        </div>
        <div class="legend-item">
          <div class="legend-color" style="background-color: #0066CC;"></div>
          <span>50-75ft (Very Deep)</span>
        </div>
        <div class="legend-item">
          <div class="legend-color" style="background-color: #0000CC;"></div>
          <span>75-100ft (Extra Deep)</span>
        </div>
        <div class="legend-item">
          <div class="legend-color" style="background-color: #000099;"></div>
          <span>100-150ft (Very Deep)</span>
        </div>
        <div class="legend-item">
          <div class="legend-color" style="background-color: #000066;"></div>
          <span>150-200ft (Extreme Deep)</span>
        </div>
        <div class="legend-item">
          <div class="legend-color" style="background-color: #000033;"></div>
          <span>200ft+ (Ultra Deep)</span>
        </div>
      </div>

      <div class="legend-section">
        <h4>Features</h4>
        <div class="legend-item">
          <div class="legend-symbol" style="background-color: transparent; border: 1px solid #666666;"></div>
          <span>Land Areas</span>
        </div>
        <div class="legend-item">
          <div class="legend-symbol" style="background-color: #FFD700; border: 2px solid #FF8C00; border-radius: 50%;"></div>
          <span>Lights</span>
        </div>
        <div class="legend-item">
          <div class="legend-symbol" style="background: repeating-linear-gradient(90deg, #FF0000, #FF0000 10px, transparent 10px, transparent 20px); height: 4px;"></div>
          <span>Navigation Lines</span>
        </div>
        <div class="legend-item">
          <div class="legend-symbol" style="background-color: #0066CC; height: 2px;"></div>
          <span>Depth Contours</span>
        </div>
        <div class="legend-item">
          <div class="legend-symbol" style="background-color: #0066CC; border-radius: 50%; width: 8px; height: 8px;"></div>
          <span>Soundings (Depth Points)</span>
        </div>
        <div class="legend-item">
          <div class="legend-symbol" style="background-color: #FFD700CC; border: 2px solid #FF8C00;"></div>
          <span>Dredged Areas</span>
        </div>
        <div class="legend-item">
          <div class="legend-symbol" style="background-color: #FF0000CC; border: 2px solid #8B0000;"></div>
          <span>Obstructions</span>
        </div>
        <div class="legend-item">
          <div class="legend-symbol" style="background-color: #8B4513; height: 3px;"></div>
          <span>Bridges</span>
        </div>
        <div class="legend-item">
          <div class="legend-symbol" style="background-color: #FF0000; border-radius: 50%; width: 10px; height: 10px;"></div>
          <span>Buoys</span>
        </div>
        <div class="legend-item">
          <div class="legend-symbol" style="background-color: #FFD700; border-radius: 50%; width: 8px; height: 8px;"></div>
          <span>Beacons</span>
        </div>
        <div class="legend-item">
          <div class="legend-symbol" style="background-color: #00FF00; border-radius: 50%; width: 8px; height: 8px;"></div>
          <span>Daymarks</span>
        </div>
        <div class="legend-item">
          <div class="legend-symbol" style="background-color: #00CED1; border-radius: 50%; width: 8px; height: 8px;"></div>
          <span>Pilot Points</span>
        </div>
        <div class="legend-item">
          <div class="legend-symbol" style="background-color: #0000FF; height: 2px;"></div>
          <span>Rivers</span>
        </div>
        <div class="legend-item">
          <div class="legend-symbol" style="background-color: #8B4513; height: 2px;"></div>
          <span>Coastline</span>
        </div>
        <div class="legend-item">
          <div class="legend-symbol" style="background: repeating-linear-gradient(90deg, #FF0000, #FF0000 10px, transparent 10px, transparent 15px); height: 3px;"></div>
          <span>Recommended Tracks</span>
        </div>
        <div class="legend-item">
          <div class="legend-symbol" style="background-color: #FF0000; height: 2px;"></div>
          <span>Fairways</span>
        </div>
        <div class="legend-item">
          <div class="legend-symbol" style="background-color: #87CEEBCC; border: 1px solid #4682B4;"></div>
          <span>Lake Areas</span>
        </div>
        <div class="legend-item">
          <div class="legend-symbol" style="background-color: #E6F3FFCC; border: 1px solid #0066CC;"></div>
          <span>Sea Areas</span>
        </div>
        <div class="legend-item">
          <div class="legend-symbol" style="background-color: #F5DEB3CC; border: 1px solid #D2691E;"></div>
          <span>Seabed Areas</span>
        </div>
      </div>

      <div class="legend-section">
        <h4>Chart Coverage</h4>
        <p><strong>Area:</strong> Washington State Coast</p>
        <p><strong>Charts:</strong> 20 ENC Charts</p>
        <p><strong>Scale:</strong> 1:22,000</p>
        <p><strong>Source:</strong> NOAA ENC</p>
      </div>
    </div>
  </div>
</div>

<style>
  .map-wrapper {
    position: relative;
    width: 100vw;
    height: 100vh;
    overflow: hidden;
  }

  .map-container {
    width: 100%;
    height: 100%;
    position: absolute;
    top: 0;
    left: 0;
  }

  .crosshair {
    position: absolute;
    top: 50%;
    left: 50%;
    transform: translate(-50%, -50%);
    width: 20px;
    height: 20px;
    pointer-events: none; /* Allow clicks to pass through */
    z-index: 1000;
  }

  .crosshair-horizontal, .crosshair-vertical {
    position: absolute;
    background-color: #FF0000;
    width: 2px;
    height: 100%;
    left: 50%;
    top: 0;
    box-shadow: 0 0 2px rgba(0, 0, 0, 0.5);
  }

  .crosshair-vertical {
    height: 2px;
    width: 100%;
    top: 50%;
    left: 0;
  }

  .depth-display {
    position: absolute;
    bottom: 20px;
    left: 20px;
    right: 20px;
    background: rgba(255, 255, 255, 0.95);
    border: 2px solid #0066CC;
    border-radius: 8px;
    padding: 8px 12px;
    font-size: 14px;
    color: #333;
    z-index: 1000;
    box-shadow: 0 2px 8px rgba(0, 0, 0, 0.2);
    max-width: none;
  }

  .depth-compact {
    display: flex;
    align-items: center;
    justify-content: space-between;
  }

  .depth-label {
    font-weight: bold;
    margin-right: 10px;
    color: #0066CC;
    font-size: 14px;
  }

  .depth-value {
    font-size: 16px;
    font-weight: bold;
    color: #333;
    flex: 1;
    text-align: right;
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
  }

  .coordinate-info {
    font-size: 14px;
    color: #666;
    margin-top: 5px;
  }

  .legend {
    position: absolute;
    top: 20px;
    right: 20px;
    background: rgba(0, 0, 0, 0.8);
    border: 1px solid #666;
    border-radius: 8px;
    padding: 12px;
    max-width: 300px;
    max-height: 80vh;
    overflow: hidden;
    box-shadow: 0 4px 8px rgba(0, 0, 0, 0.2);
    z-index: 1000;
    color: white;
    transition: all 0.3s ease-in-out;
  }

  .legend.collapsed {
    max-height: 50px;
    overflow: hidden;
  }

  .legend.collapsed .legend-content {
    opacity: 0;
    transform: translateY(-20px);
  }

  .legend-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    cursor: pointer;
    user-select: none;
    margin-bottom: 10px;
  }

  .legend-header h3 {
    margin: 0;
    padding: 0;
  }

  .legend-toggle {
    background: none;
    border: none;
    color: white;
    font-size: 20px;
    cursor: pointer;
    padding: 0 5px;
    line-height: 1;
    transition: transform 0.3s ease;
  }

  .legend-toggle:hover {
    transform: scale(1.2);
  }

  .legend-content {
    opacity: 1;
    transform: translateY(0);
    transition: all 0.3s ease-in-out;
    overflow-y: auto;
    max-height: calc(80vh - 50px);
  }

  .legend-section {
    margin-bottom: 15px;
  }

  .legend-section h4 {
    margin: 0 0 8px 0;
    color: #00CED1;
    font-size: 14px;
    font-weight: bold;
  }

  .legend-item {
    display: flex;
    align-items: center;
    margin-bottom: 4px;
    font-size: 12px;
  }

  .legend-color {
    width: 16px;
    height: 16px;
    border: 1px solid rgba(255, 255, 255, 0.3);
    margin-right: 8px;
    border-radius: 3px;
  }

  .legend-symbol {
    width: 30px;
    height: 20px;
    margin-right: 10px;
    border-radius: 3px;
  }

  .legend-section p {
    margin: 5px 0;
    font-size: 12px;
    color: #666;
  }

  .legend-section strong {
    color: #333;
  }

  :global(.ol-control) {
    background-color: rgba(255, 255, 255, 0.8);
    border-radius: 4px;
    padding: 2px;
  }

  :global(.ol-zoom) {
    top: 0.5em;
    left: 0.5em;
  }

  :global(.ol-rotate) {
    top: 0.5em;
    right: 0.5em;
  }

  :global(.ol-zoom-in, .ol-zoom-out, .ol-rotate-reset) {
    background-color: rgba(0, 60, 136, 0.7);
    color: white;
    border: none;
    border-radius: 2px;
    margin: 1px;
    padding: 0 5px;
  }

  :global(.ol-zoom-in:hover, .ol-zoom-out:hover, .ol-rotate-reset:hover) {
    background-color: rgba(0, 60, 136, 0.9);
  }

  /* Responsive design */
  @media (max-width: 768px) {
    .legend {
      top: auto;
      bottom: 80px; /* Space for depth display */
      right: 10px;
      left: 10px;
      max-width: none;
      max-height: 40vh;
      padding: 8px;
    }

    .legend.collapsed {
      max-height: 40px;
    }

    .legend-content {
      max-height: calc(40vh - 40px);
    }

    .legend h3 {
      font-size: 14px;
      margin-bottom: 8px;
    }

    .legend-section h4 {
      font-size: 12px;
    }

    .legend-item {
      font-size: 11px;
      margin-bottom: 2px;
    }

    .legend-color {
      width: 12px;
      height: 12px;
      margin-right: 6px;
    }
  }

  /* Small mobile optimization */
  @media (max-width: 480px) {
    .legend {
      bottom: 70px;
      padding: 6px;
    }

    .legend.collapsed {
      max-height: 35px;
    }

    .legend-content {
      max-height: calc(40vh - 35px);
    }

    .legend h3 {
      font-size: 13px;
      margin-bottom: 6px;
    }

    .legend-section {
      margin-bottom: 10px;
    }

    .legend-section h4 {
      font-size: 11px;
      margin-bottom: 4px;
    }

    .legend-item {
      font-size: 10px;
    }

    .legend-color {
      width: 10px;
      height: 10px;
      margin-right: 4px;
    }
  }
</style> 