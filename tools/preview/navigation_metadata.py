"""Private browser shortcuts from the actual declared toolbar/tab groups."""
import re

def screen_routes(source):
    start = source.index(' local groups={')
    stop = source.index(' local clockAt', start)
    rows = []
    for line in source[start:stop].splitlines():
        match = re.fullmatch(r"\s*(?:\[(0)\]=)?\{title='([^']+)',icon=(\d+),tabs=\{(.*?)\}\},?\s*", line)
        if match:
            tabs = [(int(page), caption) for page, caption in re.findall(r"\{(\d+),'([^']*)'\}", match[4])]
            assert tabs, 'Toolbar group has no declared tabs'
            rows.append({'home': match[1] == '0', 'title': match[2], 'icon': int(match[3]), 'tabs': tabs})
    homes = [row for row in rows if row['home']]
    toolbar = [row for row in rows if not row['home']]
    assert len(homes) == 1 and homes[0]['tabs'][0][0] == 1 and len(toolbar) == 6, 'Unknown toolbar structure'
    geometry = re.search(r'local x=(\d+)\+math.floor\(\(i-1\)\*(\d+)/6\)', source)
    assert geometry, 'Toolbar geometry not declared'
    offset, span = map(int, geometry.groups())
    routes = {1: [[20, 15]]}
    for index, row in enumerate(toolbar):
        left = offset + index * span // 6
        right = offset + (index + 1) * span // 6
        nav = [(left + right) // 2, 15]
        for tab_index, (page, _) in enumerate(row['tabs']):
            assert page not in routes, 'Duplicate page in toolbar'
            route = [nav]
            if tab_index:
                x1 = tab_index * 480 // len(row['tabs'])
                x2 = (tab_index + 1) * 480 // len(row['tabs'])
                route = route + [[(x1 + x2) // 2, 44]]
            routes[page] = route
    if 2 not in routes and 'if nextPage==2 then nextPage=7 end' in source:
        routes[2] = routes[7] # production legacy-route normalization
    assert set(routes) == set(range(1, 14)), 'Incomplete declared page set'
    pages = {'flight': 1, 'track': 2, 'power': 3, 'sensors': 4, 'data': 5,
             'sticks': 6, 'gps': 7, 'setup': 8, 'link': 9, 'arm': 10,
             'video': 11, 'diagnostics': 12, 'inputs': 13}
    return {name: routes[page] for name, page in pages.items()}
