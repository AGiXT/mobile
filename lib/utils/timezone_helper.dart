import 'package:timezone/timezone.dart' as tz;

class TimezoneHelper {
  static List<String> getTimezones() {
    // Get all timezone names
    final allTimezones = tz.timeZoneDatabase.locations.keys.toList();
    allTimezones.sort();

    // US timezones to put at the top
    final usTimezones = [
      'America/New_York',      // Eastern Time
      'America/Chicago',       // Central Time
      'America/Denver',        // Mountain Time
      'America/Los_Angeles',   // Pacific Time
      'America/Anchorage',     // Alaska Time
      'Pacific/Honolulu',      // Hawaii Time
      'America/Phoenix',       // Arizona Time (no DST)
      'America/Detroit',       // Eastern Time (Detroit)
      'America/Indianapolis',  // Eastern Time (Indianapolis)
      'America/Louisville',    // Eastern Time (Louisville)
      'America/New_Orleans',   // Central Time (New Orleans)
      'America/Houston',       // Central Time (Houston)
      'America/Dallas',        // Central Time (Dallas)
      'America/Kansas_City',   // Central Time (Kansas City)
      'America/Minneapolis',   // Central Time (Minneapolis)
      'America/St_Louis',      // Central Time (St. Louis)
      'America/Memphis',       // Central Time (Memphis)
      'America/Nashville',     // Central Time (Nashville)
      'America/Atlanta',       // Eastern Time (Atlanta)
      'America/Miami',         // Eastern Time (Miami)
      'America/Orlando',       // Eastern Time (Orlando)
      'America/Tampa',         // Eastern Time (Tampa)
      'America/Jacksonville',  // Eastern Time (Jacksonville)
      'America/Charlotte',     // Eastern Time (Charlotte)
      'America/Washington',    // Eastern Time (Washington DC)
      'America/Philadelphia',  // Eastern Time (Philadelphia)
      'America/Boston',        // Eastern Time (Boston)
      'America/Buffalo',       // Eastern Time (Buffalo)
      'America/Pittsburgh',    // Eastern Time (Pittsburgh)
      'America/Cleveland',     // Eastern Time (Cleveland)
      'America/Columbus',      // Eastern Time (Columbus)
      'America/Cincinnati',    // Eastern Time (Cincinnati)
      'America/Milwaukee',     // Central Time (Milwaukee)
      'America/Green_Bay',     // Central Time (Green Bay)
      'America/Madison',       // Central Time (Madison)
      'America/Des_Moines',    // Central Time (Des Moines)
      'America/Omaha',         // Central Time (Omaha)
      'America/Wichita',       // Central Time (Wichita)
      'America/Oklahoma_City', // Central Time (Oklahoma City)
      'America/Little_Rock',   // Central Time (Little Rock)
      'America/Mobile',        // Central Time (Mobile)
      'America/Birmingham',    // Central Time (Birmingham)
      'America/Montgomery',    // Central Time (Montgomery)
      'America/Jackson',       // Central Time (Jackson)
      'America/Baton_Rouge',   // Central Time (Baton Rouge)
      'America/Shreveport',    // Central Time (Shreveport)
      'America/Austin',        // Central Time (Austin)
      'America/San_Antonio',   // Central Time (San Antonio)
      'America/Fort_Worth',    // Central Time (Fort Worth)
      'America/El_Paso',       // Mountain Time (El Paso)
      'America/Albuquerque',   // Mountain Time (Albuquerque)
      'America/Salt_Lake_City',// Mountain Time (Salt Lake City)
      'America/Cheyenne',      // Mountain Time (Cheyenne)
      'America/Casper',        // Mountain Time (Casper)
      'America/Billings',      // Mountain Time (Billings)
      'America/Bozeman',       // Mountain Time (Bozeman)
      'America/Helena',        // Mountain Time (Helena)
      'America/Missoula',      // Mountain Time (Missoula)
      'America/Great_Falls',   // Mountain Time (Great Falls)
      'America/Denver',        // Mountain Time (Denver)
      'America/Colorado_Springs', // Mountain Time (Colorado Springs)
      'America/Pueblo',        // Mountain Time (Pueblo)
      'America/Grand_Junction', // Mountain Time (Grand Junction)
      'America/Boise',         // Mountain Time (Boise)
      'America/Pocatello',     // Mountain Time (Pocatello)
      'America/Las_Vegas',     // Pacific Time (Las Vegas)
      'America/Reno',          // Pacific Time (Reno)
      'America/Carson_City',   // Pacific Time (Carson City)
      'America/San_Francisco', // Pacific Time (San Francisco)
      'America/Oakland',       // Pacific Time (Oakland)
      'America/San_Jose',      // Pacific Time (San Jose)
      'America/Sacramento',    // Pacific Time (Sacramento)
      'America/Fresno',        // Pacific Time (Fresno)
      'America/Bakersfield',   // Pacific Time (Bakersfield)
      'America/Long_Beach',    // Pacific Time (Long Beach)
      'America/Riverside',     // Pacific Time (Riverside)
      'America/Santa_Ana',     // Pacific Time (Santa Ana)
      'America/Anaheim',       // Pacific Time (Anaheim)
      'America/San_Diego',     // Pacific Time (San Diego)
      'America/Stockton',      // Pacific Time (Stockton)
      'America/Modesto',       // Pacific Time (Modesto)
      'America/San_Bernardino', // Pacific Time (San Bernardino)
      'America/Oxnard',        // Pacific Time (Oxnard)
      'America/Glendale',      // Pacific Time (Glendale)
      'America/Huntington_Beach', // Pacific Time (Huntington Beach)
      'America/Santa_Clarita', // Pacific Time (Santa Clarita)
      'America/Garden_Grove',  // Pacific Time (Garden Grove)
      'America/Oceanside',     // Pacific Time (Oceanside)
      'America/Rancho_Cucamonga', // Pacific Time (Rancho Cucamonga)
      'America/Santa_Rosa',    // Pacific Time (Santa Rosa)
      'America/Ontario',       // Pacific Time (Ontario)
      'America/Vancouver',     // Pacific Time (Vancouver, WA)
      'America/Eugene',        // Pacific Time (Eugene)
      'America/Salem',         // Pacific Time (Salem)
      'America/Portland',      // Pacific Time (Portland)
      'America/Seattle',       // Pacific Time (Seattle)
      'America/Spokane',       // Pacific Time (Spokane)
      'America/Tacoma',        // Pacific Time (Tacoma)
      'America/Bellevue',      // Pacific Time (Bellevue)
      'America/Everett',       // Pacific Time (Everett)
      'America/Kent',          // Pacific Time (Kent)
      'America/Renton',        // Pacific Time (Renton)
      'America/Spokane_Valley', // Pacific Time (Spokane Valley)
      'America/Federal_Way',   // Pacific Time (Federal Way)
      'America/Yakima',        // Pacific Time (Yakima)
      'America/Bellingham',    // Pacific Time (Bellingham)
      'America/Kennewick',     // Pacific Time (Kennewick)
      'America/Auburn',        // Pacific Time (Auburn)
      'America/Pasco',         // Pacific Time (Pasco)
      'America/Marysville',    // Pacific Time (Marysville)
      'America/Lakewood',      // Pacific Time (Lakewood)
      'America/Redmond',       // Pacific Time (Redmond)
      'America/Shoreline',     // Pacific Time (Shoreline)
      'America/Richland',      // Pacific Time (Richland)
      'America/Kirkland',      // Pacific Time (Kirkland)
      'America/Bothell',       // Pacific Time (Bothell)
      'America/Burien',        // Pacific Time (Burien)
      'America/Normandy_Park', // Pacific Time (Normandy Park)
      'America/Tukwila',       // Pacific Time (Tukwila)
      'America/SeaTac',        // Pacific Time (SeaTac)
      'America/Des_Moines',    // Pacific Time (Des Moines, WA)
      'America/Juneau',        // Alaska Time (Juneau)
      'America/Sitka',         // Alaska Time (Sitka)
      'America/Ketchikan',     // Alaska Time (Ketchikan)
      'America/Metlakatla',    // Alaska Time (Metlakatla)
      'America/Yakutat',       // Alaska Time (Yakutat)
      'America/Nome',          // Alaska Time (Nome)
      'America/Adak',          // Hawaii-Aleutian Time (Adak)
    ];

    // Filter out US timezones that actually exist in the database
    final validUsTimezones = usTimezones.where((tz) => allTimezones.contains(tz)).toList();
    
    // Get all other timezones (excluding US ones)
    final otherTimezones = allTimezones.where((tz) => !validUsTimezones.contains(tz)).toList();
    
    // Combine: US timezones first, then all others
    return [...validUsTimezones, ...otherTimezones];
  }

  static String getTimezoneDisplayName(String timezoneName) {
    // Convert timezone names to more readable format
    final parts = timezoneName.split('/');
    if (parts.length >= 2) {
      final city = parts.last.replaceAll('_', ' ');
      final region = parts[parts.length - 2];
      
      // Special handling for America timezones
      if (parts[0] == 'America') {
        // Map common US cities to their timezone descriptions
        switch (timezoneName) {
          case 'America/New_York':
            return 'Eastern Time (New York)';
          case 'America/Chicago':
            return 'Central Time (Chicago)';
          case 'America/Denver':
            return 'Mountain Time (Denver)';
          case 'America/Los_Angeles':
            return 'Pacific Time (Los Angeles)';
          case 'America/Anchorage':
            return 'Alaska Time (Anchorage)';
          case 'America/Phoenix':
            return 'Mountain Time (Phoenix) - No DST';
          case 'Pacific/Honolulu':
            return 'Hawaii Time (Honolulu)';
          default:
            // For other US cities, show the region and city
            if (city.contains('_')) {
              return '${city} (${region})';
            } else {
              return '$city ($region)';
            }
        }
      } else {
        return '$city ($region)';
      }
    }
    
    // Fallback to the original name if parsing fails
    return timezoneName.replaceAll('_', ' ');
  }
}
