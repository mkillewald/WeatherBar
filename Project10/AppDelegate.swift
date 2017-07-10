//
//  AppDelegate.swift
//  Project10
//
//  Created by k1ds3ns4t10n on 3/19/17.
//  Copyright © 2017 Gameaholix. All rights reserved.
//

import Cocoa

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    let statusItem = NSStatusBar.system().statusItem(withLength: NSVariableStatusItemLength)
    var feed: JSON?
    var displayMode = 0
    var updateDisplayTimer: Timer?
    var fetchFeedTimer: Timer?

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Insert code here to initialize your application
        statusItem.button?.title = "Fetching..."
        statusItem.menu = NSMenu()
        addConfigurationMenuItem()
        loadSettings()
        
        // default location is Detroit, MI
        let defaultSettings = ["latitude": "42.38", "longitude": "-83.1", "apiKey": "", "statusBarOption": "-1", "units": "1"]
        UserDefaults.standard.register(defaults: defaultSettings)
        
        let nc = NotificationCenter.default
        nc.addObserver(self, selector: #selector(loadSettings), name: Notification.Name("SettingsChanged"), object: nil)
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }
    
    func addConfigurationMenuItem() {
        let separator = NSMenuItem(title: "Preferences", action: #selector(showSettings), keyEquivalent: "")
        let exit = NSMenuItem(title: "Quit WeatherBar", action: #selector(Quit), keyEquivalent: "")
        statusItem.menu?.addItem(separator)
        statusItem.menu?.addItem(exit)
    }
    
    func refreshSubmenuItems() {
        var tempUnit: String
        var windSpeedUnit: String
        var visibilityUnit: String

        let defaults = UserDefaults.standard
        if defaults.integer(forKey: "units") == 0 {
            // Metric units
            tempUnit = "C"
            windSpeedUnit = "m/s"
            visibilityUnit = "km"
        } else {
            // Imperial units
            tempUnit = "F"
            windSpeedUnit = "mph"
            visibilityUnit = "miles"
        }
        
        guard let feed = feed else { return }
        statusItem.menu?.removeAllItems()
        
        // current forecast
        statusItem.menu?.addItem(NSMenuItem(title: "Currently", action: #selector(enableMenuItem), keyEquivalent: ""))
        
        let summary = feed["currently"]["summary"].stringValue
        let temperature = feed["currently"]["temperature"].intValue
        let feelsLike = feed["currently"]["apparentTemperature"].intValue
        let humidity = feed["currently"]["humidity"].doubleValue * 100
        let cloudCover = feed["currently"]["cloudCover"].doubleValue * 100
        let precipProbability = feed["currently"]["precipProbability"].doubleValue * 100
        let precipType = feed["currently"]["precipType"].stringValue
        let windSpeed = feed["currently"]["windSpeed"].intValue
        let visibility = feed["currently"]["visibility"].doubleValue
        
        let title1 = "\(summary) \(temperature)°\(tempUnit) feels like \(feelsLike)°\(tempUnit) Wind: \(windSpeed) \(windSpeedUnit)"
        let title2 = "Humidity: \(Int(humidity))% Cloud Cover: \(Int(cloudCover))% Visibility: \(visibility) \(visibilityUnit)"
        var title3 = "\(Int(precipProbability))% chance of "
        if precipProbability > 0 {
            title3 += "\(precipType)"
        } else {
            title3 += "precipitation"
        }
        
        let menuItem1 = NSMenuItem(title: title1, action: #selector(enableMenuItem), keyEquivalent: "")
        menuItem1.indentationLevel = 1
        let menuItem2 = NSMenuItem(title: title2, action: #selector(enableMenuItem), keyEquivalent: "")
        menuItem2.indentationLevel = 1
        let menuItem3 = NSMenuItem(title: title3, action: #selector(enableMenuItem), keyEquivalent: "")
        menuItem3.indentationLevel = 1

        statusItem.menu?.addItem(menuItem1)
        statusItem.menu?.addItem(menuItem2)
        statusItem.menu?.addItem(menuItem3)
        
        // 12 hour forecast
        statusItem.menu?.addItem(NSMenuItem.separator())
        statusItem.menu?.addItem(NSMenuItem(title: "12 Hour Forecast", action: #selector(enableMenuItem), keyEquivalent: ""))
        
        // create a 12 hour forecast by pulling 13 hours from the fetched feed and removing the data at index 0 (the current hour)
        var twelveHourFeed = feed["hourly"]["data"].arrayValue.prefix(13)
        twelveHourFeed.remove(at: 0)
        
        for forecast in twelveHourFeed {
            let date = Date(timeIntervalSince1970: forecast["time"].doubleValue)
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            let formattedDate = formatter.string(from: date)
            
            let summary = forecast["summary"].stringValue
            let temperature = forecast["temperature"].intValue
            let precipProbability = forecast["precipProbability"].doubleValue * 100
            let precipType = forecast["precipType"].stringValue
            let windSpeed = feed["currently"]["windSpeed"].intValue
            let title = "\(formattedDate): \(summary) \(temperature)°\(tempUnit) Wind: \(windSpeed) \(windSpeedUnit)"
            
            let menuItem = NSMenuItem(title: title, action: #selector(enableMenuItem), keyEquivalent: "")
            menuItem.indentationLevel = 1
            statusItem.menu?.addItem(menuItem)
            
            if precipProbability > 0 {
                let title2 = "\(Int(precipProbability))% chance of \(precipType)"
                let menuItem2 = NSMenuItem(title: title2, action: #selector(enableMenuItem), keyEquivalent: "")
                menuItem2.indentationLevel = 2
                statusItem.menu?.addItem(menuItem2)
            }
        }
        
        // 7 day forecast
        statusItem.menu?.addItem(NSMenuItem.separator())
        statusItem.menu?.addItem(NSMenuItem(title: "7 Day Forecast", action: #selector(enableMenuItem), keyEquivalent: ""))
        
        for forecast in feed["daily"]["data"].arrayValue.prefix(7) {
            let date = Date(timeIntervalSince1970: forecast["time"].doubleValue)
            let calendar = NSCalendar(calendarIdentifier: NSCalendar.Identifier.gregorian)!
            let components = calendar.components(.weekday, from: date)
            
            let daysOfWeek = ["Error", "Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
            var dayOfWeek = daysOfWeek[0]

            if let weekdayIndex = components.weekday {
                dayOfWeek = daysOfWeek[weekdayIndex]
            }
            
            let summary = forecast["summary"].stringValue
            let temperatureMin = forecast["temperatureMin"].intValue
            let temperatureMax = forecast["temperatureMax"].intValue
            let precipProbability = forecast["precipProbability"].doubleValue * 100
            let precipType = forecast["precipType"].stringValue
            let windSpeed = forecast["windSpeed"].intValue
            
            let title1 = "\(dayOfWeek): \(summary)"
            let title2 = "Low: \(temperatureMin)°\(tempUnit) High: \(temperatureMax)°\(tempUnit) Wind: \(windSpeed) \(windSpeedUnit)"
            var title3 = "\(Int(precipProbability))% chance of "
            if precipProbability > 0 {
                title3 += "\(precipType)"
            } else {
                title3 += "precipitation"
            }
            
            let menuItem1 = NSMenuItem(title: title1, action: #selector(enableMenuItem), keyEquivalent: "")
            menuItem1.indentationLevel = 1
            let menuItem2 = NSMenuItem(title: title2, action: #selector(enableMenuItem), keyEquivalent: "")
            menuItem2.indentationLevel = 2
            let menuItem3 = NSMenuItem(title: title3, action: #selector(enableMenuItem), keyEquivalent: "")
            menuItem3.indentationLevel = 2
            statusItem.menu?.addItem(menuItem1)
            statusItem.menu?.addItem(menuItem2)
            statusItem.menu?.addItem(menuItem3)
        }
        
        statusItem.menu?.addItem(NSMenuItem.separator())
        addConfigurationMenuItem()
    }
    
    func enableMenuItem() {
        // this stub is needed to show menu items as enabled instead of 'greyed out'
    }
    
    func showSettings(_ sender: NSMenuItem) {
        updateDisplayTimer?.invalidate()
        let storyboard = NSStoryboard(name: "Main", bundle: nil)
        guard let vc = storyboard.instantiateController(withIdentifier: "ViewController") as? ViewController else { return }
        
        let popoverView = NSPopover()
        popoverView.contentViewController = vc
        popoverView.behavior = .transient
        popoverView.show(relativeTo: statusItem.button!.bounds, of: statusItem.button!, preferredEdge: .maxY)
    }
    
    func fetchFeed() {
        let defaults = UserDefaults.standard
        
        guard let apiKey = defaults.string(forKey: "apiKey") else { return }
        guard !apiKey.isEmpty else {
            statusItem.button?.title = "No API key"
            return
        }
        
        DispatchQueue.global(qos: .utility).async { [unowned self] in
            let latitude = defaults.double(forKey: "latitude")
            let longitude = defaults.double(forKey: "longitude")
            
            var dataSource = "https://api.darksky.net/forecast/\(apiKey)/\(latitude),\(longitude)"
            
            if defaults.integer(forKey: "units") == 0 {
                dataSource += "?units=si"
            }
            
            guard let url = URL(string: dataSource) else { return }
            guard let data = try? Data(contentsOf: url) else {
                DispatchQueue.main.async { [unowned self] in
                    self.statusItem.button?.title = "Bad API call"
                }
                
                return
            }
            
            let newFeed = JSON(data: data)

            DispatchQueue.main.async {
                self.feed = newFeed
                self.updateDisplay()
                self.refreshSubmenuItems()
            }
        }
    }
    
    func loadSettings() {
        displayMode = UserDefaults.standard.integer(forKey: "statusBarOption")
        configureUpdateDisplayTimer()
        fetchFeedTimer = Timer.scheduledTimer(timeInterval: 60 * 5, target: self, selector: #selector(fetchFeed), userInfo: nil, repeats: true)
        fetchFeedTimer?.tolerance = 60
        fetchFeed()
    }
    
    func updateDisplay() {
        
        var tempUnit: String
        var windSpeedUnit: String
        var visibilityUnit: String
        
        let defaults = UserDefaults.standard
        if defaults.integer(forKey: "units") == 0 {
            // Metric units
            tempUnit = "C"
            windSpeedUnit = "m/s"
            visibilityUnit = "km"
        } else {
            // Imperial units
            tempUnit = "F"
            windSpeedUnit = "mph"
            visibilityUnit = "miles"
        }
        
        guard let feed = feed else { return }
        
        var text = "Error"
        
        switch displayMode {
        case 0:
            // show summary text with current temperature
            if let summary = feed["currently"]["summary"].string {
                if let temperature = feed["currently"]["temperature"].int {
                    text = summary + " \(temperature)°\(tempUnit)"
                }
            }
        case 1:
            // show humidity
            if let humidity = feed["currently"]["humidity"].double{
                text = "Humidity: \(Int(humidity * 100))%"
            }
        case 2:
            // show chance of rain
            if let rain = feed["currently"]["precipProbability"].double {
                text = "Precipitation: \(Int(rain * 100))%"
            }
        case 3:
            // show cloud cover
            if let cloud = feed["currently"]["cloudCover"].double {
                text = "Cloud Cover: \(Int(cloud * 100))%"
            }
        case 4:
            // show wind speed
            if let windSpeed = feed["currently"]["windSpeed"].int {
                text = "Wind: \(windSpeed) \(windSpeedUnit)"
            }
        case 5:
            // show visibility
            if let visibility = feed["currently"]["visibility"].double {
                text = "Visibility: \(visibility) \(visibilityUnit)"
            }
        default:
            // this should not be reached
            break
        }
        
        statusItem.button?.title = text
    }
    
    func changeDisplayMode() {
        displayMode += 1
        
        if displayMode > 5 {
            displayMode = 0
        }
        
        updateDisplay()
    }
    
    func configureUpdateDisplayTimer() {
        guard let statusBarMode = UserDefaults.standard.string(forKey: "statusBarOption") else { return }
        
        if statusBarMode == "-1" {
            displayMode = 0
            updateDisplayTimer = Timer.scheduledTimer(timeInterval: 2, target: self, selector: #selector(changeDisplayMode), userInfo: nil, repeats: true)
        } else {
            updateDisplayTimer?.invalidate()
        }
    }
    
    func Quit(send: AnyObject?) {
        NSLog("Exit")
        NSApplication.shared().terminate(nil)
    }

}
