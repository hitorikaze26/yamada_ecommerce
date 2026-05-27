"""Philippine locations API for geolocation data."""

from flask import Blueprint, jsonify, request
from flask_cors import cross_origin

philippine_locations_bp = Blueprint('philippine_locations', __name__)

# PSGC code to region name mapping (Philippine Standard Geographic Codes)
PSGC_REGION_MAP = {
    # NCR
    "130000000": "Metro Manila",
    # Region I (Ilocos)
    "010000000": "Luzon",
    # Region II (Cagayan Valley)
    "020000000": "Luzon",
    # Region III (Central Luzon)
    "030000000": "Luzon",
    # Region IV-A (CALABARZON)
    "040000000": "Luzon",
    # Region IV-B (MIMAROPA)
    "170000000": "Luzon",
    # Region V (Bicol)
    "050000000": "Luzon",
    # CAR (Cordillera)
    "140000000": "Luzon",
    # Region VI (Western Visayas)
    "060000000": "Visayas",
    # Region VII (Central Visayas)
    "070000000": "Visayas",
    # Region VIII (Eastern Visayas)
    "080000000": "Visayas",
    # Region IX (Zamboanga)
    "090000000": "Mindanao",
    # Region X (Northern Mindanao)
    "100000000": "Mindanao",
    # Region XI (Davao)
    "110000000": "Mindanao",
    # Region XII (SOCCSKSARGEN)
    "120000000": "Mindanao",
    # CARAGA
    "160000000": "Mindanao",
    # BARMM
    "190000000": "Mindanao",
}

def normalize_region(region_input: str) -> str:
    """Convert PSGC code or region name to internal region key."""
    if not region_input:
        return None
    
    # Direct lookup in PSGC map first
    if region_input in PSGC_REGION_MAP:
        return PSGC_REGION_MAP[region_input]
    
    # Try matching with trailing zeros removed
    normalized_input = region_input.rstrip('0')
    for code, name in PSGC_REGION_MAP.items():
        if code.rstrip('0') == normalized_input:
            return name
    
    # Try direct name match (case-insensitive)
    region_lower = region_input.lower()
    for key in PHILIPPINE_LOCATIONS.keys():
        if key.lower() == region_lower:
            return key
    
    # Try matching common variations
    variations = {
        'ncr': 'Metro Manila',
        'metro manila': 'Metro Manila',
        'calabarzon': 'Luzon',
        'mimaropa': 'Luzon',
        'region 1': 'Luzon',
        'region 2': 'Luzon',
        'region 3': 'Luzon',
        'region 4a': 'Luzon',
        'region 4b': 'Luzon',
        'region 5': 'Luzon',
        'region 6': 'Visayas',
        'region 7': 'Visayas',
        'region 8': 'Visayas',
        'region 9': 'Mindanao',
        'region 10': 'Mindanao',
        'region 11': 'Mindanao',
        'region 12': 'Mindanao',
        'caraga': 'Mindanao',
        'barmm': 'Mindanao',
    }
    if region_lower in variations:
        return variations[region_lower]
    
    return None

# Philippine regions, provinces, and cities data
# Special case: NCR (Metro Manila) has NO provinces - cities are directly under region
PHILIPPINE_LOCATIONS = {
    "Metro Manila": {
        "cities": [
            "Manila", "Quezon City", "Caloocan", "Makati", "Pasay",
            "Pasig", "Taguig", "Parañaque", "Mandaluyong", "San Juan",
            "Las Piñas", "Muntinlupa", "Marikina", "Valenzuela", "Malabon",
            "Navotas", "San Jose del Monte", "Pateros"
        ]
    },
    "Luzon": {
        "provinces": {
            "Ilocos Region": {
                "cities": ["Laoag", "Vigan", "Candon", "Batac", "San Fernando"]
            },
            "Cagayan Valley": {
                "cities": ["Tuguegarao", "Cauayan", "Ilagan", "Santiago", "Cabarroguis"]
            },
            "Central Luzon": {
                "cities": ["San Fernando", "Angeles", "Mabalacat", "San Jose", "Cabanatuan", "Gapan", "Muñoz", "Palayan"]
            },
            "Calabarzon": {
                "cities": ["Calamba", "Lipa", "Batangas", "Santa Rosa", "Biñan", "San Pablo", "Cabuyao", "General Trias", "Tanza", "Dasmariñas"]
            },
            "Mimaropa": {
                "cities": ["Calapan", "Puerto Princesa", "Odiongan", "Romblon", "Bongao"]
            },
            "Bicol Region": {
                "cities": ["Legazpi", "Naga", "Iriga", "Tabaco", "Ligao", "Masbate City", "Sorsogon City"]
            },
            "Cordillera Administrative Region": {
                "cities": ["Baguio", "Tabuk", "Bontoc", "Laoag", "Ifugao"]
            }
        }
    },
    "Visayas": {
        "provinces": {
            "Western Visayas": {
                "cities": ["Iloilo", "Bacolod", "Roxas", "San Carlos", "Cadiz", "Silay", "Victorias", "Passi", "Kabankalan", "Sagay"]
            },
            "Central Visayas": {
                "cities": ["Cebu", "Mandaue", "Lapu-Lapu", "Toledo", "Danao", "Talisay", "Naga", "Bogo", "Carcar", "Tagbilaran"]
            },
            "Eastern Visayas": {
                "cities": ["Tacloban", "Ormoc", "Baybay", "Calbayog", "Catbalogan", "Borongan", "Maasin"]
            }
        }
    },
    "Mindanao": {
        "provinces": {
            "Northern Mindanao": {
                "cities": ["Cagayan de Oro", "Iligan", "Malaybalay", "Valencia", "Oroquieta", "Ozamiz", "Tangub", "Gingoog"]
            },
            "Davao Region": {
                "cities": ["Davao", "Tagum", "Digos", "Mati", "Panabo", "Island Garden City of Samal", "Davao del Sur"]
            },
            "Soccsksargen": {
                "cities": ["General Santos", "Koronadal", "Kidapawan", "Cotabato", "Tacurong", "Glan", "Midsayap"]
            },
            "Caraga": {
                "cities": ["Butuan", "Surigao", "Bislig", "Tandag", "Cabadbaran", "Bayugan"]
            },
            "Zamboanga Peninsula": {
                "cities": ["Zamboanga", "Dapitan", "Dipolog", "Pagadian", "Isabela"]
            },
            "Bangsamoro": {
                "cities": ["Cotabato", "Marawi", "Lamitan"]
            }
        }
    }
}

@philippine_locations_bp.route('/api/philippine-locations/regions', methods=['GET'])
@cross_origin()
def get_regions():
    """Get all Philippine regions with PSGC codes."""
    # Map internal region names to representative PSGC codes
    try:
        REGION_CODES = {
            "Metro Manila": "130000000",
            "Luzon": "040000000",  # CALABARZON as representative
            "Visayas": "070000000",  # Central Visayas as representative
            "Mindanao": "110000000",  # Davao Region as representative
        }
        
        regions_list = [
            {"code": REGION_CODES.get(name, name), "name": name}
            for name in PHILIPPINE_LOCATIONS.keys()
        ]
        
        return jsonify({
            "regions": regions_list
        })
    except Exception as e:
        return jsonify({"error": "Failed to retrieve regions", "details": str(e)}), 500
    
@philippine_locations_bp.route('/api/philippine-locations/provinces/<region>', methods=['GET'])
@cross_origin()
def get_provinces(region):
    """Get all provinces for a specific region (accepts PSGC code or name).
    Returns empty array for NCR since it has no provinces."""
    try:
        region_name = normalize_region(region)
        if not region_name or region_name not in PHILIPPINE_LOCATIONS:
            return jsonify({"error": "Region not found", "received": region}), 404
        
        # NCR has no provinces - return empty
        if "provinces" not in PHILIPPINE_LOCATIONS[region_name]:
            return jsonify({
                "region": region_name,
                "provinces": []
            })
        
        provinces_list = [
            {"code": name, "name": name}
            for name in PHILIPPINE_LOCATIONS[region_name]["provinces"].keys()
        ]
        
        return jsonify({
            "region": region_name,
            "provinces": provinces_list
        })
    except Exception as e:
        return jsonify({"error": "Failed to retrieve provinces", "details": str(e)}), 500

@philippine_locations_bp.route('/api/philippine-locations/cities/<region>/<province>', methods=['GET'])
@cross_origin()
def get_cities(region, province):
    """Get all cities for a specific region and province (accepts PSGC code or name).
    For NCR (no province), use 'none' as province parameter."""
    region_name = normalize_region(region)
    if not region_name or region_name not in PHILIPPINE_LOCATIONS:
        return jsonify({"error": "Region not found", "received": region}), 404
    
    # NCR has no provinces - cities are directly under region
    if "cities" in PHILIPPINE_LOCATIONS[region_name]:
        cities_list = [
            {"code": name, "name": name}
            for name in PHILIPPINE_LOCATIONS[region_name]["cities"]
        ]
        return jsonify({
            "region": region_name,
            "province": None,
            "cities": cities_list
        })
    
    # Normal region with provinces
    if province not in PHILIPPINE_LOCATIONS[region_name]["provinces"]:
        return jsonify({"error": "Province not found", "received": province}), 404
    
    cities_list = [
        {"code": name, "name": name}
        for name in PHILIPPINE_LOCATIONS[region_name]["provinces"][province]["cities"]
    ]
    
    return jsonify({
        "region": region_name,
        "province": province,
        "cities": cities_list
    })

@philippine_locations_bp.route('/api/philippine-locations/barangays/<region>/<province>/<city>', methods=['GET'])
@cross_origin()
def get_barangays(region, province, city):
    """Get barangays for a specific city (accepts PSGC code or name for region)."""
    region_name = normalize_region(region)
    if not region_name or region_name not in PHILIPPINE_LOCATIONS:
        return jsonify({"error": "Region not found", "received": region}), 404
    if province not in PHILIPPINE_LOCATIONS[region_name]["provinces"]:
        return jsonify({"error": "Province not found", "received": province}), 404
    if city not in PHILIPPINE_LOCATIONS[region_name]["provinces"][province]["cities"]:
        return jsonify({"error": "City not found", "received": city}), 404
    
    # Return common barangay names - in production this would query a full database
    common_barangays = [
        "Poblacion", "Barangay 1", "Barangay 2", "Barangay 3", "Barangay 4", "Barangay 5",
        "San Isidro", "San Jose", "San Roque", "Santa Cruz", "Santa Maria", "Santo Niño",
        "Bagumbayan", "Kalayaan", "Maginhawa", "Maligaya", "Masagana", "Pag-asa",
        "Mabini", "Rizal", "Bonifacio", "Luna", "Del Pilar", "Aguinaldo"
    ]
    
    barangays_list = [
        {"code": name, "name": name}
        for name in common_barangays
    ]
    
    return jsonify({
        "region": region_name,
        "province": province,
        "city": city,
        "barangays": barangays_list
    })


@philippine_locations_bp.route('/api/philippine-locations/all', methods=['GET'])
@cross_origin()
def get_all_locations():
    """Get all Philippine locations structured."""
    return jsonify(PHILIPPINE_LOCATIONS)

@philippine_locations_bp.route('/api/philippine-locations/search', methods=['GET'])
@cross_origin()
def search_locations():
    """Search for locations by query."""
    query = request.args.get('q', '').lower()
    if not query:
        return jsonify({"error": "Query parameter 'q' is required"}), 400
    
    results = []
    for region_name, region_data in PHILIPPINE_LOCATIONS.items():
        for province_name, province_data in region_data["provinces"].items():
            for city in province_data["cities"]:
                if (query in region_name.lower() or 
                    query in province_name.lower() or 
                    query in city.lower()):
                    results.append({
                        "region": region_name,
                        "province": province_name,
                        "city": city
                    })
    
    return jsonify({"results": results[:50]})  # Limit to 50 results
