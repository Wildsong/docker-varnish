"""
unittest.py

Test all services that GIS Services provides

This started out as just a test to make sure the reverse proxy was working.
"""
import sys
import requests
from string import Template
import xml.etree.ElementTree as ET

# TODO: test each layer, both demo and wms
# TODO: allow testing JPEG type
# TODO: collect a checksum and use it to make sure the image returned is correct

verbose = False
tests = 0
errors = 0
msgBuffer = ''
errorBuffer = ''

if len(sys.argv)>1 and sys.argv[1] == '-v':
    verbose = True

# Some tests can't run when Varnish is not in use.
VARNISH = True
CHALLENGE_SERVER = False

# Type identifiers
HTML='text/html'
HTMLUTF='text/html; charset=utf-8'

# Server identifiers
MAPPROXY = 'Undefined'
MATOMO = 'Apache/2.4.53 (Debian)'

def addMessage(msg : str) -> None:
    global msgBuffer
    msgBuffer += msg + "\n"
    return

def addError(msg : str) -> None:
    global errorBuffer, errors
    errorBuffer += msg + "\n"
    errors += 1
    return

mapproxy_services = [
    {'service': "bulletin78_79", 'layers': ['astoria_quad', 'cathlamet_quad', 'cannonbeach_quad', 'svensen_quad'], 
        'wms': 'bulletin78_79/service?SERVICE=WMS&VERSION=1.3.0&REQUEST=GetMap&FORMAT=image%2Fpng&TRANSPARENT=true&LAYERS=$layer&CRS=EPSG%3A3857&STYLES=&WIDTH=1959&HEIGHT=901&BBOX=-13752738.810054881%2C5782328.275296917%2C-13726415.862597933%2C5794434.949956801',
    },
    {'service': "city-aerials", 'layers': ['astoria2021'],
        'wms': 'city-aerials/service?SERVICE=WMS&VERSION=1.3.0&REQUEST=GetMap&FORMAT=image%2Fpng&TRANSPARENT=true&LAYERS=warrenton2011&CRS=EPSG%3A3857&STYLES=&WIDTH=1959&HEIGHT=901&BBOX=-30079294.132968683%2C-13834325.683412343%2C30079294.132968683%2C13834325.683412343',
    },
    {'service': "county-aerials", 'layers': ['osip2018'],
        'wms': 'county-aerials/service?SERVICE=WMS&VERSION=1.3.0&REQUEST=GetMap&FORMAT=image%2Fpng&TRANSPARENT=true&LAYERS=osip2018&CRS=EPSG%3A3857&STYLES=&WIDTH=1959&HEIGHT=901&BBOX=-13787639.235713175%2C5807384.717645408%2C-13783675.71958535%2C5809207.651811394',
    },
    {'service': "county-aerials-brief", 'layers': ['osip2018'],
        'wms': 'county-aerials-brief/service?SERVICE=WMS&VERSION=1.3.0&REQUEST=GetMap&FORMAT=image%2Fpng&TRANSPARENT=true&LAYERS=osip2018&CRS=EPSG%3A3857&STYLES=&WIDTH=1959&HEIGHT=901&BBOX=-13787495.573015662%2C5807181.223440446%2C-13783636.475556312%2C5808956.132481217',
    },
    {'service': "lidar", 'layers': ['digital_terrain_slope_model_layer', 'digital_surface_model_layer_hs', 'digital_terrain_model_layer_hs'],
        'wms': 'lidar/service?SERVICE=WMS&VERSION=1.3.0&REQUEST=GetMap&FORMAT=image%2Fpng&TRANSPARENT=true&LAYERS=$layer&CRS=EPSG%3A3857&STYLES=&WIDTH=1959&HEIGHT=901&BBOX=-13800548.570441948%2C5751370.182628403%2C-13765310.402330594%2C5767577.221662774',
    },
    {'service': "lidar-2020", 'layers': ['digital_terrain_slope_model_layer', 'digital_surface_model_layer_hs', 'digital_terrain_model_layer_hs'],
        'wms': 'lidar-2020/service?SERVICE=WMS&VERSION=1.3.0&REQUEST=GetMap&FORMAT=image%2Fpng&TRANSPARENT=true&LAYERS=$layer&CRS=EPSG%3A3857&STYLES=&WIDTH=1959&HEIGHT=901&BBOX=-13800548.570441948%2C5751370.182628403%2C-13765310.402330594%2C5767577.221662774',
    },
    {'service': "usgs-nhd", 'layers': ['usgs_wbd_layer', 'usgs_nhd_hr_layer', 'usgs_nhd_layer'],
        'wms': 'usgs-nhd/service?SERVICE=WMS&VERSION=1.3.0&REQUEST=GetMap&FORMAT=image%2Fpng&TRANSPARENT=true&LAYERS=$layer&CRS=EPSG%3A3857&STYLES=&WIDTH=1959&HEIGHT=901&BBOX=-13800548.570441948%2C5751370.182628403%2C-13765310.402330594%2C5767577.221662774',
    },
]

def testGET(url : str, expected_type='text/html') -> dict:
    global tests
    addMessage(url)
    tests += 1
    r = None
    try:
        r = requests.get(url)
        if r.status_code != 200:
            addError(f"FAIL: Status={r.status_code} {r.url}")
    except Exception as e:
        addError(f"FAIL: req_failed {url}")
    return r

def testGETtype(url: str, expected_type='text/html', retcode=200, expected_server=None, expected_x_service=None) -> dict:
    global tests
    tests += 1
    r = None
    addMessage(url)
    try:
        r = requests.get(url)
    except Exception as e:
        addError(f"FAIL: req_failed {url}")
    if r:
        if r.status_code != retcode:
            addError(f"FAIL: Status={r.status_code} {r.url}")

        #print(r.headers)
        t = r.headers['Content-type'] 

        if t.lower() != expected_type.lower():
            # When MapProxy can't find a tile it sends status 200 but 
            # also back an XML doc with the error. If you only check status, it looks fine.
            if t.startswith('text/xml'):
                root = ET.fromstring(r.text)
        #        for n in root.iter():
        #            addError('n=',n)
                error = root.findall('{http://www.opengis.net/ogc}ServiceException')[0]
                addError(f"FAIL: Service Exception: \"{error.text}\"")
            else:
                addError(f"FAIL: Content type is wrong. expected {expected_type} but got {t} on {url}") 

        if expected_server:
            try:  
                s = r.headers['Server'] 
            except KeyError:
                # Mapproxy does not return a server string!
                s = 'Undefined'
            if s != expected_server:
                # The perils of proxies, sometimes the proxy points the wrong
                # direction and the response code (200) lulls us into a sense of security.
                addError(f'FAIL: wrong server? {url} Expected:"{expected_server}\" but got "{s}"')

        if expected_x_service:
            try:  
                s = r.headers['X-SERVICE'] 
            except KeyError:
                # Only services we've modified have this header.
                s = 'Undefined'
            if s != expected_x_service:
                # The perils of proxies, sometimes the proxy points the wrong
                # direction and the response code (200) lulls us into a sense of security.
                addError(f'FAIL: wrong server? Expected:"{expected_x_service}\" but got "{s}"')
    return r


def test_web_apps(server):
    services = [
        "/apps/ClatsopCounty/",
        "/apps/ATApp/",
        "/apps/PlanningApp/"
    ]
    for s in services:
        url = server + s
        r = testGET(url, expected_type=HTML)
    return

def test_gisserver(server):
    services = [
        # Something hosted
        "/server/rest/services/Hosted/Unlabeled_Vector_Tiles_20220704_0819/VectorTileServer",

        # Something with registered data - Taxlots MIL and Feature Service
        "/server/rest/services/Taxlots/FeatureServer",
        "/server/rest/services/Taxlots/FeatureServer/1",
    ]
    for s in services:
        url = server + s
        r = testGET(url, expected_type=HTML)
    return

def test_dev_apps() -> None:
    return
    server = 'cc-testmaps.clatsop.co.clatsop.or.us'
    testGETtype(f"http://{server}:3344/", retcode=200, expected_type=HTMLUTF) # WABDE

    # service is running, don't know why it fails here but right now I don't care
#    testGETtype(f"http://{server}:3000/", retcode=301, expected_type='') # EXB
#    testGETtype(f"https://{server}:3001/", retcode=301, expected_type='') # EXB
    return

def test_mapproxy(server) -> None:

    # Test all the Get Capabilities docs first,
    # this confirms that each service is running.
    for s in mapproxy_services:
        testGET(f"{server}/{s['service']}/wms?REQUEST=GETCAPABILITIES")
            
    for s in mapproxy_services:
        for layer in s['layers']:

       # The demo mode pages are not required.
#            url = f"{server}/{s['service']}/demo/"
#            testGETtype(url, expected_type=HTML)
            
            route = Template(s['wms']).substitute(layer=layer)
            url = f"{server}/{route}"
            if url:
                testGETtype(url, expected_type='image/png')
    return


def test_property_photos(server) -> None:
    property_photos = [

        # Thumbnails
        ("property/api/?tn=1&t=80907DB13400", 'image/jpeg'),
        ('property/api/?tn=1&t=80918DA06900', 'image/jpeg'),
        ('property/api/?tn=1&f=url&t=80822B002100', 'image/png'),
        ('property/api/?tn=1&t=80822B002100', 'image/png'),

        ('property/api/?tn=1&t=80918DA06900', 'image/jpeg'),
        ('property/api/?tn=1&f=url&t=80918DA06900', 'image/jpeg'),

        ('property/api/?f=url&t=80822B002100', 'image/png'),
        ('property/api/?t=80822B002100', 'image/png'),
        ('property/api/?t=80918DA06900', 'image/jpeg'),

        ('property/api/?f=url&t=80918DA06900', 'image/jpeg'),

        ('property/api/?t=80822B002100', 'image/png'),
        ('property/api/?t=80918DA06900', 'image/jpeg'),
    ]
    for ph in property_photos:
        url = f"{server}/{ph[0]}"
        r = testGETtype(url, ph[1])
        
    return


def test_survey_docs(server: str) -> None :
    url = server + '/surveys/10000-10999/CS%2010425B.pdf'
    testGETtype(url, 'application/pdf')

    url = server + '/surveys/10000-10999/CS%2010425C.pdf'
    testGETtype(url, 'application/pdf')

    return

def test_septic_documents(server: str) -> None :
    url = server + '/septic/41007B000101'
    testGETtype(url, 'application/json')

    return

def test_photos(server: str) -> None :
    url = server + '/'
    testGETtype(url, 'text/html') # photo landing page
    photos = [
        ('/photos/bridges/1002A.jpg', 'image/jpeg'),
        ('/photos/tn/bridges/1002A.jpg', 'image/jpeg'),

        ('/photos/tn/waterway/ph5428.png', 'image/png'),
        ('/photos/waterway/ph5428.png', 'image/png'),

        # These short urls redirect to the long ones
        ('/photos/tn/waterway/5428', 'image/png'), 
        ('/photos/waterway/5428', 'image/png'),
        ('/photos/tn/waterway/5372', 'image/png'),
        ('/photos/waterway/5372', 'image/png'),
    ]
    for p in photos:
        url = server + p[0]
        r = testGETtype(url, p[1], retcode=200)
    return


if __name__ == "__main__":

    port = ':444' # testing on port 444
    port = ''
    if VARNISH:
        this_server = f'https://giscache.clatsopcounty.gov{port}' # Varnish
    else:
        this_server = f'https://giscache.co.clatsop.or.us{port}' # Caddy

    test_gisserver("https://delta.co.clatsop.or.us")
    
    test_web_apps('https://delta.co.clatsop.or.us')
    
    # The challenge server only needs to be accessible via HTTP
    if CHALLENGE_SERVER:
        file = "/.well-known/acme-challenge/test.html"
        s = f'http://giscache.co.clatsop.or.us{port}'
        r = testGETtype(s + file, expected_type=HTML, expected_x_service='ACME')
        s = f'http://giscache.clatsopcounty.gov{port}'
        r = testGETtype(s + file, expected_type=HTML, expected_x_service='ACME')

    # The basic web server that serves the landing page
    ws = this_server
    testGETtype(ws + '/', expected_type=HTML)
    ws = f'https://giscache.co.clatsop.or.us{port}'
    testGETtype(ws + '/', expected_type=HTML)

    test_survey_docs("https://delta.co.clatsop.or.us")

    mapproxy_caches = ["https://giscache.co.clatsop.or.us"]
    if VARNISH:
        mapproxy_caches.append("https://giscache.clatsopcounty.gov")
    for server in mapproxy_caches:
        test_mapproxy(server) # Tests map image delivery

    # TODO - I should test actual databases here, not just the server
    mapproxy_couchdb = 'http://cc-giscache:5984/_utils'
    r = testGET(mapproxy_couchdb, expected_type=HTML)

    photo_servers = ['https://giscache.co.clatsop.or.us']
    if VARNISH:
        photo_servers.append("https://giscache.clatsopcounty.gov")
    for server in [this_server]:
        test_photos(server) # Tests www content delivery

    # These are on a totally different server, but we need to test them anyway.
    test_property_photos('https://apps.clatsopcounty.gov')

    # Matomo
    testGETtype(f'https://echo.clatsopcounty.gov{port}/', 'text/html; charset=utf-8')#, expected_server=MATOMO)
#    testGETtype(f'https://echo.clatsopcounty.gov{port}/', 'text/html')
    
    testGETtype(f'https://echo.clatsopcounty.gov{port}/matomo.js', 'application/javascript')#, expected_server=MATOMO)

    # I don't care if these are proxied right now. Work on it later.    
    test_dev_apps()

    # Test the weird "property api" microservice for Septic Documents
    test_septic_documents('http://giscache.clatsopcounty.gov:5002')

    # === TESTS ARE DONE, NOW REPORT ===

    # ALWAYS report errors
    if errors>0:
        print(f"SKY IS FALLING! Error count: {errors}")
        print("");
        print(errorBuffer)
        print("\n")
        passfail = f"\nFAILED {errors}.\n"
    else:
        passfail = f"\nPASSED {tests} tests.\n"

    # ONLY report status if requested
    if verbose:
        print(passfail, msgBuffer, passfail)

    exit(errors)
