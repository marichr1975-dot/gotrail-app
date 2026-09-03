package app.organicmaps;

import java.util.ArrayList;
import java.util.Collections;
import java.util.List;

/** Temporary in-memory results from the last GoTr-Ail offline zone analysis. */
public final class GoTrailPoiStore
{
  public enum Category { HUT, FOUNTAIN, WATERFALL, PARKING, VIEWPOINT }

  public static final class Poi
  {
    public final String title;
    public final String type;
    public final Category category;
    public final double lat;
    public final double lon;
    public final double distanceKm;

    public Poi(String title, String type, Category category, double lat, double lon, double distanceKm)
    {
      this.title = title;
      this.type = type;
      this.category = category;
      this.lat = lat;
      this.lon = lon;
      this.distanceKm = distanceKm;
    }
  }

  private static final List<Poi> ITEMS = new ArrayList<>();
  private static double sCenterLat;
  private static double sCenterLon;
  private static boolean sShowOnMap;

  private GoTrailPoiStore() {}

  public static synchronized void set(double centerLat, double centerLon, List<Poi> items)
  {
    sCenterLat = centerLat;
    sCenterLon = centerLon;
    ITEMS.clear();
    ITEMS.addAll(items);
    sShowOnMap = false;
  }

  public static synchronized List<Poi> getItems()
  {
    return Collections.unmodifiableList(new ArrayList<>(ITEMS));
  }

  public static synchronized double getCenterLat() { return sCenterLat; }
  public static synchronized double getCenterLon() { return sCenterLon; }
  public static synchronized void requestShowOnMap() { sShowOnMap = true; }
  public static synchronized boolean shouldShowOnMap() { return sShowOnMap && !ITEMS.isEmpty(); }
  public static synchronized void clearShowRequest() { sShowOnMap = false; }
}
