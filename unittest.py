"""
unittest.py

Test all services that are proxied by Varnish.
"""
import requests
import xml.etree.ElementTree as ET

# TODO: test each layer, both demo and wms
# TODO: allow testing JPEG type
# TODO: collect a checksum and use it to make sure the image returned is correct

mapproxy_services = [
    {'service': "bulletin78_79", 'layers': ['astoria_quad'], 
        'wms': 'bulletin78_79/service?SERVICE=WMS&VERSION=1.3.0&REQUEST=GetMap&FORMAT=image%2Fpng&TRANSPARENT=true&LAYERS=svensen_quad&CRS=EPSG%3A3857&STYLES=&WIDTH=1959&HEIGHT=901&BBOX=-13752738.810054881%2C5782328.275296917%2C-13726415.862597933%2C5794434.949956801',
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
    {'service': "lidar-2020", 'layers': ['digital_terrain_elevaion'],
        'wms': 'lidar-2020/service?SERVICE=WMS&VERSION=1.3.0&REQUEST=GetMap&FORMAT=image%2Fpng&TRANSPARENT=true&LAYERS=digital_terrain_model_layer_hs&CRS=EPSG%3A3857&STYLES=&WIDTH=1959&HEIGHT=901&BBOX=-13800548.570441948%2C5751370.182628403%2C-13765310.402330594%2C5767577.221662774',
    },
]

def testGET(url : str, expected_type='text/html') -> dict:
    try:
        r = requests.get(url)
    except Exception as e:
        raise Exception(f"Request failed with {e}")
    assert (r.status_code == 200), f"FAIL: {r.status_code} Test of \"{r.url}\""
    t = r.headers['Content-type'] 

    # When MapProxy can't find a tile it sends status 200 but 
    # also back an XML doc with the error. So if you only check status, it looks fine.
    if t == 'text/xml':
        root = ET.fromstring(r.text)
#        for n in root.iter():
#            print('n=',n)
        error = root.findall('{http://www.opengis.net/ogc}ServiceException')[0]
        print(r.status_code, r.url)
        assert False, f"Service Exception: \"{error.text}\""

    #print(url, t,expected_type)
    assert (t==expected_type), f"Content type is wrong. expected {expected_type} but got {t} on {url}" 
    return r


def test_web_server() -> None:
    # First test the basic web server running as part of Varnish.
    server = "foxtrot.clatsopcounty.gov"
    r = requests.get(f"https://{server}/")
    assert (r.status_code == 200), f"FAIL: Test of web server {server} returned {r.status_code}"
    #print(r.url)

    r = requests.get(f"https://{server}/favicon.ico")
    assert (r.status_code == 200), f"FAIL: Test of web server {server} returned {r.status_code}"

    r = requests.get(f"https://{server}/.well-known/acme-challenge/test.html")
    assert (r.status_code == 200), f"FAIL: Test of challenge server {server} returned {r.status_code}"

    return


def test_proxies() -> None:
    r = requests.get(f"https://{server}/webappbuilder")
    assert (r.status_code == 200), f"FAIL: Web AppBuilder {server} returned {r.status_code}"

    # Experience builder proxy is not working. It's only an experiment anyway.
    #r = requests.get(f"https://{server}/page/set-portalurl")
    #assert (r.status_code == 200), f"FAIL: Experience Builder {server} returned {r.status_code}"

    return

def test_mapproxy() -> None:
    for server in ["foxtrot.clatsopcounty.gov", "giscache.co.clatsop.or.us"]:

        # Test all the Get Capabilities docs first,
        # this confirms that each service is running.

        for s in mapproxy_services:
            r = requests.get(f"https://{server}/{s['service']}/wms?REQUEST=GETCAPABILITIES")
            assert (r.status_code == 200), f"FAIL: {r.status_code} Test of \"{r.url}\""
                
        # The demo mode pages are not required but what the heck.

        for s in mapproxy_services:
            for layer in s['layers']:
                url = f"https://{server}/{s['service']}/demo/"
                r = testGET(url, expected_type='text/html')
                
            url = f"https://{server}/{s['wms']}"
            if url:
                r = testGET(url, expected_type='image/png')
                #print(r.status_code, r.url)

    return


def test_property_photos() -> None:
    server = 'apps.clatsopcounty.gov'
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
        url = f"https://{server}/{ph[0]}"
        testGET(url, ph[1])
    
    return


def test_surveys() -> None :
    url = 'https://delta.co.clatsop.or.us/surveys/10000-10999/CS%2010425B.pdf'
    testGET(url, 'application/pdf')

    url = 'https://delta.co.clatsop.or.us/surveys/10000-10999/CS%2010425C.pdf'
    testGET(url, 'application/pdf')

    return


def test_photos(server) -> None :
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
        testGET(url, p[1])
    return


if __name__ == "__main__":

    test_photos('https://foxtrot.clatsopcounty.gov')

    test_property_photos()

    test_web_server()
    test_mapproxy()
    test_proxies


# Other services -- you know, if I were to use the cache for these
# it might even speed things up a tiny tiny bit. Not enough to matter.
# Property photos
waterway = "https://giscache.co.clatsop.or.us/photos/waterway/5355"
# Bridges
# Survey docs (PDFs)
survey="https://delta.co.clatsop.or.us/surveys/10000-10999/CS%2010425A.pdf"

print("All Varnish unit tests ran successfully.")
