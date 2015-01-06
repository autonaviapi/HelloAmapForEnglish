//
//  ViewController.m
//  AMapDmeo
//
//  Created by 王菲 on 14-12-24.
//  Copyright (c) 2014年 autonavi. All rights reserved.
//

#import "ViewController.h"
#import "POIAnnotation.h"

#define converturl @"http://restapi.amap.com/v3/assistant/coordinate/convert?key=897210d6f68d6a63cfc84f86d96ec5e3&coordsys=gps&locations=";

#define APIKey      @"95ed2da3e9f4ece6319afbc437fc0b01"
#define GeoPlaceHolder @"Searh or enter an address"

@interface ViewController ()<MKMapViewDelegate, AMapSearchDelegate,UISearchBarDelegate, UISearchDisplayDelegate, UITableViewDataSource, UITableViewDelegate>
{
    
    MKMapView *_mapView;
    
    CLLocation *_currentLocation;//当前坐标
    
    CLLocation *_convertLocation;//转换后的坐标
    
    CLLocationManager *_locationManager;
    
    AMapSearchAPI *_search;
    
    UISearchBar *_searchBar;
    
    UISearchDisplayController *_displayController;
    
    NSMutableArray *_tips;
    
}


@end

@implementation ViewController


#pragma mark - Utility

/* 逆地理编码 搜索. */
- (void)reverseGeocoding
{
    
    AMapReGeocodeSearchRequest *request = [[AMapReGeocodeSearchRequest alloc] init];
    
    request.location = [AMapGeoPoint locationWithLatitude:_currentLocation.coordinate.latitude longitude:_currentLocation.coordinate.longitude];
    
    [_search AMapReGoecodeSearch:request];
}


/* POI 搜索. */
- (void)searchPOIWithKey:(NSString *)key adcode:(NSString *)adcode
{
    if (key.length == 0)
    {
        return;
    }
    
    AMapPlaceSearchRequest *place = [[AMapPlaceSearchRequest alloc] init];
    place.keywords = key;
    
    place.requireExtension = YES;
    
    
    if (adcode.length > 0)
    {
        place.city = @[adcode];
    }
    
    [_search AMapPlaceSearch:place];
}

/* 输入提示 搜索.*/
- (void)searchTipsWithKey:(NSString *)key
{
    if (key.length == 0)
    {
        return;
    }
    
    AMapInputTipsSearchRequest *tips = [[AMapInputTipsSearchRequest alloc] init];
    tips.keywords = key;
    [_search AMapInputTipsSearch:tips];
}

/* 清除annotation. */
- (void)clear
{
    [_mapView removeAnnotations:_mapView.annotations];
}

- (void)clearAndSearchGeocodeWithKey:(NSString *)key adcode:(NSString *)adcode
{
    /* 清除annotation. */
    [self clear];
    
    [self searchPOIWithKey:key adcode:adcode];
}

#pragma mark - Initialization

- (void)initSearchBar
{
    _searchBar = [[UISearchBar alloc] initWithFrame:CGRectMake(0, 21, CGRectGetWidth(self.view.bounds), 44)];
    _searchBar.barStyle     = UIBarStyleBlackOpaque;
    _searchBar.translucent  = YES;
    _searchBar.delegate     = self;
    _searchBar.placeholder  = GeoPlaceHolder;
    _searchBar.keyboardType = UIKeyboardTypeDefault;
    
    [self.view addSubview:_searchBar];
}

- (void)initSearchDisplay
{
    _displayController = [[UISearchDisplayController alloc] initWithSearchBar:_searchBar contentsController:self];
    _displayController.delegate                = self;
    _displayController.searchResultsDataSource = self;
    _displayController.searchResultsDelegate   = self;
}


- (void) initLocation
{
    if(nil == _locationManager)
    {
        _locationManager = [[CLLocationManager alloc] init];
        
    }
    
    if([[[UIDevice currentDevice] systemVersion] floatValue] >= 8.0)
    {
        [_locationManager requestAlwaysAuthorization];
    }
}

- (void) initMapView{
    
    _mapView = [[MKMapView alloc] initWithFrame:CGRectMake(0, 21, CGRectGetWidth(self.view.bounds), CGRectGetHeight(self.view.bounds))];
    _mapView.delegate = self;
    
    _mapView.showsUserLocation = YES;
    
    [_mapView setUserTrackingMode:MKUserTrackingModeFollow];
    
    
    [self.view addSubview:_mapView];
    
}

- (void)initSearch
{
    _search = [[AMapSearchAPI alloc] initWithSearchKey:APIKey Delegate:self];
    _search.language = AMapSearchLanguage_en;
}


#pragma mark - Life Cycle

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
    _tips = [NSMutableArray array];
    
    [self initLocation];
    
    [self initMapView];
    
    [self initSearch];
    
    [self initSearchBar];
    
    [self initSearchDisplay];
    
}


#pragma mark - MKMapViewDelegate

- (void)mapView:(MKMapView *)mapView didUpdateUserLocation:(MKUserLocation *)userLocation
{
    _currentLocation = [userLocation.location copy];
    
    if(_currentLocation)
    {
        [self reverseGeocoding];
    }
}

#pragma mark - AMapSearchDelegate

- (void)searchRequest:(id)request didFailWithError:(NSError *)error
{
    NSLog(@"request :%@, error :%@", request, error);
}

- (void)onReGeocodeSearchDone:(AMapReGeocodeSearchRequest *)request response:(AMapReGeocodeSearchResponse *)response
{
    NSLog(@"response :%@", response);
    
    NSString *title = response.regeocode.addressComponent.city;
    if (title.length == 0)
    {
        title = response.regeocode.addressComponent.province;
    }
    
    _mapView.userLocation.title = title;
    _mapView.userLocation.subtitle = response.regeocode.formattedAddress;
    
}

/* 输入提示回调. */
- (void)onInputTipsSearchDone:(AMapInputTipsSearchRequest *)request response:(AMapInputTipsSearchResponse *)response
{
    [_tips setArray:response.tips];
    
    [_displayController.searchResultsTableView reloadData];
}

/* POI 搜索回调. */
- (void)onPlaceSearchDone:(AMapPlaceSearchRequest *)request response:(AMapPlaceSearchResponse *)respons
{
    if (respons.pois.count == 0)
    {
        return;
    }
    
    NSMutableArray *poiAnnotations = [NSMutableArray arrayWithCapacity:respons.pois.count];
    
    [respons.pois enumerateObjectsUsingBlock:^(AMapPOI *obj, NSUInteger idx, BOOL *stop) {
        
        [poiAnnotations addObject:[[POIAnnotation alloc] initWithPOI:obj]];
        
    }];
    
    /* 将结果以annotation的形式加载到地图上. */
    [_mapView addAnnotations:poiAnnotations];
    
    /* 如果只有一个结果，设置其为中心点. */
    if (poiAnnotations.count == 1)
    {
        _mapView.centerCoordinate = [poiAnnotations[0] coordinate];
    }
    /* 如果有多个结果, 设置地图使所有的annotation都可见. */
    else
    {
        [_mapView showAnnotations:poiAnnotations animated:NO];
    }
}

#pragma mark - UISearchBarDelegate

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar
{
    // NSString *key = searchBar.text;
    
    AMapTip *tip = _tips[0];
    [self clearAndSearchGeocodeWithKey:tip.name adcode:tip.adcode];
    
    [_displayController setActive:NO animated:NO];
    
    _searchBar.placeholder = tip.name;
}

#pragma mark - UISearchDisplayDelegate

- (BOOL)searchDisplayController:(UISearchDisplayController *)controller shouldReloadTableForSearchString:(NSString *)searchString
{
    [self searchTipsWithKey:searchString];
    
    return YES;
}

#pragma mark - UITableViewDataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return _tips.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *tipCellIdentifier = @"tipCellIdentifier";
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:tipCellIdentifier];
    
    if (cell == nil)
    {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle
                                      reuseIdentifier:tipCellIdentifier];
    }
    
    AMapTip *tip = _tips[indexPath.row];
    
    cell.textLabel.text = tip.name;
    cell.detailTextLabel.text = tip.adcode;
    
    return cell;
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    AMapTip *tip = _tips[indexPath.row];
    
    [self clearAndSearchGeocodeWithKey:tip.name adcode:tip.adcode];
    
    [_displayController setActive:NO animated:NO];
    
    _searchBar.placeholder = tip.name;
}



@end
