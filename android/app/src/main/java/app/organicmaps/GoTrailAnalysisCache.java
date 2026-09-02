package app.organicmaps;

import android.content.Context;
import android.content.SharedPreferences;
import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import org.json.JSONArray;
import org.json.JSONObject;
import java.util.ArrayList;
import java.util.List;

/** Small offline LRU cache for the last five GoTr-Ail zone analyses. */
final class GoTrailAnalysisCache
{
  private static final String PREFS = "gotrail_analysis_cache";
  private static final String KEY = "zones";
  private static final int MAX_ZONES = 5;
  // A searched town may resolve a little away from the exact previous screen centre.
  private static final double MATCH_KM = 2.5;

  static final class Entry
  {
    final double lat, lon;
    final ArrayList<GoTrailPoiStore.Poi> items;
    Entry(double lat, double lon, ArrayList<GoTrailPoiStore.Poi> items)
    { this.lat = lat; this.lon = lon; this.items = items; }
  }

  private GoTrailAnalysisCache() {}

  static void save(@NonNull Context context, double lat, double lon, @NonNull List<GoTrailPoiStore.Poi> items)
  {
    try
    {
      final JSONArray old = read(context);
      final JSONArray out = new JSONArray();
      out.put(toJson(lat, lon, items));
      for (int i = 0; i < old.length() && out.length() < MAX_ZONES; i++)
      {
        final JSONObject zone = old.optJSONObject(i);
        if (zone == null) continue;
        if (distanceKm(lat, lon, zone.optDouble("lat"), zone.optDouble("lon")) < MATCH_KM) continue;
        out.put(zone);
      }
      prefs(context).edit().putString(KEY, out.toString()).apply();
    }
    catch (Exception ignored) {}
  }

  /** Returns the most recently completed analysis, regardless of the current map centre.
   *  Used by the RISULTATI button after the user has focused a POI on the map. */
  @Nullable static Entry getLatest(@NonNull Context context)
  {
    try
    {
      final JSONArray zones = read(context);
      if (zones.length() == 0) return null;
      final JSONObject latest = zones.optJSONObject(0);
      return latest == null ? null : fromJson(latest);
    }
    catch (Exception ignored) { return null; }
  }

  @Nullable static Entry findNearest(@NonNull Context context, double lat, double lon)
  {
    try
    {
      final JSONArray zones = read(context);
      JSONObject best = null;
      double bestKm = MATCH_KM;
      for (int i = 0; i < zones.length(); i++)
      {
        final JSONObject z = zones.optJSONObject(i);
        if (z == null) continue;
        final double km = distanceKm(lat, lon, z.optDouble("lat"), z.optDouble("lon"));
        if (km <= bestKm) { bestKm = km; best = z; }
      }
      return best == null ? null : fromJson(best);
    }
    catch (Exception ignored) { return null; }
  }

  /** Finds the nearest cached analysis within a caller-defined radius.
   *  Used by the map UI, whose analysed-zone radius is 5 km. */
  @Nullable static Entry findNearestWithin(@NonNull Context context, double lat, double lon, double maxKm)
  {
    try
    {
      final JSONArray zones = read(context);
      JSONObject best = null;
      double bestKm = maxKm;
      for (int i = 0; i < zones.length(); i++)
      {
        final JSONObject z = zones.optJSONObject(i);
        if (z == null) continue;
        final double km = distanceKm(lat, lon, z.optDouble("lat"), z.optDouble("lon"));
        if (km <= bestKm) { bestKm = km; best = z; }
      }
      return best == null ? null : fromJson(best);
    }
    catch (Exception ignored) { return null; }
  }

  private static SharedPreferences prefs(Context c) { return c.getSharedPreferences(PREFS, Context.MODE_PRIVATE); }
  private static JSONArray read(Context c)
  {
    try { return new JSONArray(prefs(c).getString(KEY, "[]")); }
    catch (Exception ignored) { return new JSONArray(); }
  }

  private static JSONObject toJson(double lat, double lon, List<GoTrailPoiStore.Poi> items) throws Exception
  {
    final JSONObject z = new JSONObject(); z.put("lat", lat); z.put("lon", lon);
    final JSONArray a = new JSONArray();
    for (GoTrailPoiStore.Poi p : items)
    {
      final JSONObject o = new JSONObject();
      o.put("title", p.title); o.put("type", p.type); o.put("category", p.category.name());
      o.put("lat", p.lat); o.put("lon", p.lon); o.put("distance", p.distanceKm); a.put(o);
    }
    z.put("items", a); return z;
  }

  private static Entry fromJson(JSONObject z) throws Exception
  {
    final ArrayList<GoTrailPoiStore.Poi> items = new ArrayList<>();
    final JSONArray a = z.optJSONArray("items");
    if (a != null) for (int i = 0; i < a.length(); i++)
    {
      final JSONObject o = a.getJSONObject(i);
      final GoTrailPoiStore.Category cat = GoTrailPoiStore.Category.valueOf(o.getString("category"));
      items.add(new GoTrailPoiStore.Poi(o.optString("title"), o.optString("type"), cat,
          o.optDouble("lat"), o.optDouble("lon"), o.optDouble("distance")));
    }
    return new Entry(z.optDouble("lat"), z.optDouble("lon"), items);
  }

  private static double distanceKm(double lat1, double lon1, double lat2, double lon2)
  {
    final double r = 6371.0088, dLat = Math.toRadians(lat2-lat1), dLon = Math.toRadians(lon2-lon1);
    final double a = Math.sin(dLat/2)*Math.sin(dLat/2) + Math.cos(Math.toRadians(lat1))*Math.cos(Math.toRadians(lat2))*Math.sin(dLon/2)*Math.sin(dLon/2);
    return r * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1-a));
  }
}
