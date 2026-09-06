/// Use the system region, never the preferred UI language. HK/MO/TW use AdMob.
bool usesDirichletForRegion(String? regionCode) =>
    regionCode?.toUpperCase() == 'CN';
