package app.organicmaps;

import android.app.Activity;
import android.graphics.Color;
import android.graphics.Typeface;
import android.graphics.drawable.GradientDrawable;
import android.graphics.drawable.Drawable;
import android.content.Intent;
import android.net.Uri;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.text.TextUtils;
import android.text.SpannableString;
import android.text.Spanned;
import android.text.style.ForegroundColorSpan;
import android.text.style.ImageSpan;
import android.text.style.RelativeSizeSpan;
import android.text.style.SubscriptSpan;
import android.text.style.TabStopSpan;
import android.view.Gravity;
import android.view.View;
import android.widget.LinearLayout;
import android.widget.ProgressBar;
import android.widget.ScrollView;
import android.widget.TextView;
import androidx.annotation.NonNull;
import app.organicmaps.sdk.Framework;
import app.organicmaps.sdk.search.SearchEngine;
import app.organicmaps.sdk.search.SearchListener;
import app.organicmaps.sdk.search.SearchResult;
import java.util.ArrayList;
import java.util.Collections;
import java.util.Comparator;
import java.util.LinkedHashMap;
import java.util.Locale;
import java.util.Map;

/** GoTr-Ail V25: real OFFLINE zone analysis in 5 km.
 *  Categories: huts, drinking fountains, waterfalls, parking and viewpoints. */
public class GoTrailAnalyzeActivity extends Activity implements SearchListener
{
  private static final double RADIUS_KM = 5.0;
  private static final String[] QUERIES = {
    "rifugio",
    "cascata", "waterfall",
    "parcheggio", "parking"
  };
  private static final GoTrailPoiStore.Category[] QUERY_CATEGORIES = {
    GoTrailPoiStore.Category.HUT,
    GoTrailPoiStore.Category.WATERFALL, GoTrailPoiStore.Category.WATERFALL,
    GoTrailPoiStore.Category.PARKING, GoTrailPoiStore.Category.PARKING
  };

  private final Map<String, GoTrailPoiStore.Poi> mFound = new LinkedHashMap<>();
  private int mQueryIndex = -1;
  private long mTimestamp;
  private double mCenterLat;
  private double mCenterLon;

  private ProgressBar mProgress;
  private TextView mProgressPercent;
  private TextView mStatus;
  private TextView mCount;
  private LinearLayout mResults;
  private TextView mStepHut;
  private TextView mStepFountain;
  private TextView mStepWaterfall;
  private TextView mStepParking;
  private TextView mStepViewpoint;
  private TextView mShowMap;
  private final Handler mUiHandler = new Handler(Looper.getMainLooper());
  private GoTrailPoiStore.Category mActiveCategory;
  private int mDotFrame = 0;
  private final Runnable mDotsAnimator = new Runnable()
  {
    @Override public void run()
    {
      if (mActiveCategory == null) return;
      updateActiveStep();
      mDotFrame = (mDotFrame + 1) % 16;
      mUiHandler.postDelayed(this, 120);
    }
  };

  private int dp(int value) { return Math.round(value * getResources().getDisplayMetrics().density); }

  private TextView text(String value, int size, int style, int color)
  {
    TextView v = new TextView(this);
    v.setText(value); v.setTextSize(size); v.setTypeface(Typeface.DEFAULT, style); v.setTextColor(color);
    return v;
  }

  @Override protected void onCreate(Bundle savedInstanceState)
  {
    super.onCreate(savedInstanceState);
    buildUi();
    final double[] center = Framework.nativeGetScreenRectCenter();
    if (center == null || center.length < 2) { showError("Non riesco a leggere il centro della mappa."); return; }
    mCenterLat = center[0]; mCenterLon = center[1];

    // v25 fix risultati per zona: se RISULTATI arriva dalla mappa, MwmActivity
    // passa il centro esatto della cache riconosciuta sotto la mappa (es. Cortina).
    // In questo modo non vengono aperti per errore gli ultimi risultati globali (es. Alleghe).
    if (getIntent().getBooleanExtra("gotrail_results_only", false))
    {
      GoTrailAnalysisCache.Entry cached = null;
      if (getIntent().hasExtra("gotrail_results_center_lat")
          && getIntent().hasExtra("gotrail_results_center_lon"))
      {
        final double requestedLat = getIntent().getDoubleExtra("gotrail_results_center_lat", mCenterLat);
        final double requestedLon = getIntent().getDoubleExtra("gotrail_results_center_lon", mCenterLon);
        cached = GoTrailAnalysisCache.findNearestWithin(this, requestedLat, requestedLon, 0.10);
      }

      // Fallback per i vecchi ingressi a RISULTATI che non specificano una zona.
      if (cached == null)
        cached = GoTrailAnalysisCache.getLatest(this);

      if (cached != null)
      {
        mCenterLat = cached.lat;
        mCenterLon = cached.lon;
        final ArrayList<GoTrailPoiStore.Poi> cleanCachedItems = filterVisibleCategories(cached.items);
        GoTrailPoiStore.set(cached.lat, cached.lon, cleanCachedItems);
        showCachedResults(cleanCachedItems);
        return;
      }
    }

    SearchEngine.INSTANCE.addListener(this);
    SearchEngine.INSTANCE.cancel();
    nextSearch();
  }

  private void buildUi()
  {
    final LinearLayout root = new LinearLayout(this);
    root.setOrientation(LinearLayout.VERTICAL);
    root.setPadding(dp(20), dp(30), dp(20), dp(18));
    root.setBackgroundColor(Color.rgb(245, 248, 252));

    root.addView(text("Analizzo la zona", 27, Typeface.BOLD, Color.rgb(11, 95, 215)));

    // V25.2: il RESCAN permette di aggiornare una zona gia' presente in cache
    // (es. Alleghe) senza dover cancellare o aspettare che scada l'analisi precedente.
    final LinearLayout radiusRow = new LinearLayout(this);
    radiusRow.setOrientation(LinearLayout.HORIZONTAL);
    radiusRow.setGravity(Gravity.CENTER_VERTICAL);

    final TextView radius = text("Raggio 5 km", 16, Typeface.BOLD, Color.rgb(32, 168, 90));
    radiusRow.addView(radius, new LinearLayout.LayoutParams(0, -2, 1f));

    final TextView rescan = text("↻", 20, Typeface.BOLD, Color.WHITE);
    rescan.setGravity(Gravity.CENTER);
    rescan.setPadding(dp(8), dp(1), dp(8), dp(3));
    final GradientDrawable rescanBg = new GradientDrawable();
    rescanBg.setColor(Color.rgb(210, 35, 35));
    rescanBg.setStroke(dp(1), Color.rgb(210, 35, 35));
    rescanBg.setCornerRadius(dp(15));
    rescan.setBackground(rescanBg);
    rescan.setOnClickListener(v -> forceRescan());
    LinearLayout.LayoutParams rescanLp = new LinearLayout.LayoutParams(-2, -2);
    rescanLp.leftMargin = dp(18);
    radiusRow.addView(rescan, rescanLp);

    LinearLayout.LayoutParams rp = new LinearLayout.LayoutParams(-1, -2);
    rp.topMargin = dp(6);
    root.addView(radiusRow, rp);

    final LinearLayout progressRow = new LinearLayout(this);
    progressRow.setOrientation(LinearLayout.HORIZONTAL);
    progressRow.setGravity(Gravity.CENTER_VERTICAL);

    mProgress = new ProgressBar(this, null, android.R.attr.progressBarStyleHorizontal);
    mProgress.setMax(100);
    LinearLayout.LayoutParams barParams = new LinearLayout.LayoutParams(0, dp(12), 1f);
    progressRow.addView(mProgress, barParams);

    mProgressPercent = text("5%", 17, Typeface.BOLD, Color.rgb(11, 95, 215));
    mProgressPercent.setGravity(Gravity.END | Gravity.CENTER_VERTICAL);
    LinearLayout.LayoutParams percentParams = new LinearLayout.LayoutParams(dp(58), -2);
    percentParams.leftMargin = dp(10);
    progressRow.addView(mProgressPercent, percentParams);

    LinearLayout.LayoutParams pp = new LinearLayout.LayoutParams(-1, -2);
    pp.topMargin = dp(22);
    root.addView(progressRow, pp);
    setProgressValue(5);

    mStatus = text("Analisi delle mappe locali in corso…", 17, Typeface.NORMAL, Color.DKGRAY);
    LinearLayout.LayoutParams sp = new LinearLayout.LayoutParams(-1, -2); sp.topMargin = dp(12); root.addView(mStatus, sp);

    final LinearLayout steps = new LinearLayout(this);
    steps.setOrientation(LinearLayout.VERTICAL);
    mStepHut = text("Rifugi", 19, Typeface.BOLD, Color.DKGRAY);
    mStepFountain = text("Fontane", 19, Typeface.BOLD, Color.DKGRAY);
    mStepWaterfall = text("Cascate", 19, Typeface.BOLD, Color.DKGRAY);
    mStepParking = text("Parcheggi", 19, Typeface.BOLD, Color.DKGRAY);
    mStepViewpoint = text("Panoramici", 19, Typeface.BOLD, Color.DKGRAY);
    configureStepView(mStepHut);
    configureStepView(mStepFountain);
    configureStepView(mStepWaterfall);
    configureStepView(mStepParking);
    configureStepView(mStepViewpoint);

    // V30.5 PULITA: categorie eliminate dall'analisi.
    mStepFountain.setVisibility(View.GONE);
    mStepViewpoint.setVisibility(View.GONE);
    steps.addView(mStepHut);
    LinearLayout.LayoutParams swp = new LinearLayout.LayoutParams(-1, -2); swp.topMargin = dp(8); steps.addView(mStepWaterfall, swp);
    LinearLayout.LayoutParams spp = new LinearLayout.LayoutParams(-1, -2); spp.topMargin = dp(8); steps.addView(mStepParking, spp);
    LinearLayout.LayoutParams stp = new LinearLayout.LayoutParams(-1, -2); stp.topMargin = dp(12); root.addView(steps, stp);

    mCount = text("", 20, Typeface.BOLD, Color.rgb(11, 95, 215));
    LinearLayout.LayoutParams cp = new LinearLayout.LayoutParams(-1, -2); cp.topMargin = dp(20); root.addView(mCount, cp);

    final ScrollView scroll = new ScrollView(this);
    mResults = new LinearLayout(this); mResults.setOrientation(LinearLayout.VERTICAL);
    scroll.addView(mResults, new ScrollView.LayoutParams(-1, -2));
    LinearLayout.LayoutParams scrollParams = new LinearLayout.LayoutParams(-1, 0, 1f); scrollParams.topMargin = dp(8); root.addView(scroll, scrollParams);

    final TextView back = text("MOSTRA ANALISI SULLA MAPPA", 16, Typeface.BOLD, Color.WHITE);
    mShowMap = back;
    back.setVisibility(View.GONE);
    back.setGravity(Gravity.CENTER);
    final GradientDrawable showMapBg = new GradientDrawable();
    showMapBg.setColor(Color.rgb(11, 95, 215));
    showMapBg.setCornerRadius(dp(24));
    back.setBackground(showMapBg);
    back.setPadding(dp(10), dp(14), dp(10), dp(14));
    back.setOnClickListener(v -> {
      // XX17: use Organic Maps native API pins instead of Android screen overlays.
      // Native pins are geographically anchored and therefore follow pan/zoom correctly.
      final Uri.Builder builder = new Uri.Builder()
          .scheme("om")
          .authority("map")
          .appendQueryParameter("v", "1")
          .appendQueryParameter("appname", "GoTr-Ail");

      for (GoTrailPoiStore.Poi item : GoTrailPoiStore.getItems())
      {
        // V27.1: per i parcheggi non creare un secondo placemark GoTr-Ail.
        // Resta visibile soltanto la P nativa di Organic Maps.
        if (item.category == GoTrailPoiStore.Category.PARKING)
          continue;

        // Keep the known-good native green pin. Only decorate its label by category.
        final String prefix = categoryPrefix(item.category);
        final String pinStyle = categoryPinStyle(item.category);
        builder.appendQueryParameter("ll", String.format(Locale.US, "%.7f,%.7f", item.lat, item.lon));
        builder.appendQueryParameter("n", prefix + item.title);
        builder.appendQueryParameter("id", item.category.name());
        builder.appendQueryParameter("s", pinStyle);
      }

      final Intent mapIntent = new Intent(Intent.ACTION_VIEW, builder.build(), this, MwmActivity.class);
      // v24: entrando dalla schermata di analisi il pulsante blu RISULTATI deve
      // essere visibile immediatamente, senza aspettare il tap su un POI.
      mapIntent.putExtra("gotrail_show_results", true);
      mapIntent.putExtra("gotrail_analysis_center_lat", mCenterLat);
      mapIntent.putExtra("gotrail_analysis_center_lon", mCenterLon);
      mapIntent.addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP | Intent.FLAG_ACTIVITY_SINGLE_TOP);
      startActivity(mapIntent);
      finish();
    });
    LinearLayout.LayoutParams bp = new LinearLayout.LayoutParams(-1, -2); bp.topMargin = dp(12); root.addView(back, bp);
    setContentView(root);
  }

  @Override public void onBackPressed()
  {
    // v25 flow: dalla schermata risultati il secondo Indietro porta sempre alla Home.
    final Intent home = new Intent(this, GoTrailHomeActivity.class);
    home.addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP | Intent.FLAG_ACTIVITY_SINGLE_TOP);
    startActivity(home);
    finish();
  }

  private void forceRescan()
  {
    stopDotsAnimation();
    SearchEngine.INSTANCE.cancel();
    SearchEngine.INSTANCE.removeListener(this);

    mFound.clear();
    mQueryIndex = -1;
    mTimestamp = 0L;
    if (mResults != null) mResults.removeAllViews();
    if (mCount != null) mCount.setVisibility(View.GONE);
    if (mShowMap != null) mShowMap.setVisibility(View.GONE);

    resetStep(mStepHut, "Rifugi");
    resetStep(mStepFountain, "Fontane");
    resetStep(mStepWaterfall, "Cascate");
    resetStep(mStepParking, "Parcheggi");
    resetStep(mStepViewpoint, "Panoramici");

    setProgressValue(5);
    mStatus.setText("Nuova analisi delle mappe locali in corso…");

    SearchEngine.INSTANCE.addListener(this);
    nextSearch();
  }

  private void resetStep(@NonNull TextView view, @NonNull String label)
  {
    view.setText(label);
    view.setTextColor(Color.DKGRAY);
    view.setCompoundDrawables(null, null, null, null);
    view.setVisibility(View.VISIBLE);
  }

  private void nextSearch()
  {
    mQueryIndex++;
    if (mQueryIndex >= QUERIES.length) { finishAnalysis(); return; }
    final String query = QUERIES[mQueryIndex];
    final int progress = 15 + (int) Math.round((70.0 * mQueryIndex) / Math.max(1, QUERIES.length - 1));
    final GoTrailPoiStore.Category target = QUERY_CATEGORIES[mQueryIndex];
    setProgressValue(progress);
    mStatus.setText("Analisi delle mappe locali in corso…");
    setActiveCategory(target);
    mTimestamp = System.nanoTime();
    final boolean started = SearchEngine.INSTANCE.search(this, query, false, mTimestamp, true, mCenterLat, mCenterLon);
    if (!started) nextSearch();
  }

  @Override public void onResultsUpdate(@NonNull SearchResult[] results, long timestamp)
  {
    if (timestamp != mTimestamp) return;
    for (SearchResult result : results)
    {
      if (result == null || result.type != SearchResult.TYPE_RESULT) continue;
      final GoTrailPoiStore.Category category = classify(result);
      if (category == null || !matchesCurrentQuery(category)) continue;
      final double distance = distanceKm(mCenterLat, mCenterLon, result.lat, result.lon);
      if (distance > RADIUS_KM) continue;
      final String fallback = categoryFallback(category);
      final String title = TextUtils.isEmpty(result.name) ? fallback : result.name;
      final String type = result.description != null && !TextUtils.isEmpty(result.description.localizedFeatureType) ? result.description.localizedFeatureType : fallback;
      final String key = String.format(Locale.US, "%.5f|%.5f|%s", result.lat, result.lon, title.toLowerCase(Locale.ROOT));
      mFound.put(key, new GoTrailPoiStore.Poi(title, type, category, result.lat, result.lon, distance));
    }
  }

  @Override public void onResultsEnd(long timestamp) { if (timestamp == mTimestamp) nextSearch(); }

  private boolean matchesCurrentQuery(GoTrailPoiStore.Category category)
  {
    return mQueryIndex >= 0 && mQueryIndex < QUERY_CATEGORIES.length &&
           category == QUERY_CATEGORIES[mQueryIndex];
  }

  private GoTrailPoiStore.Category classify(@NonNull SearchResult result)
  {
    if (result.description == null || TextUtils.isEmpty(result.description.localizedFeatureType)) return null;
    final String type = result.description.localizedFeatureType.toLowerCase(Locale.ROOT);
    final String name = TextUtils.isEmpty(result.name) ? "" : result.name.toLowerCase(Locale.ROOT);
    // XX17: bivouacs are deliberately excluded both by feature type and by POI name.
    if (type.contains("bivacco") || type.contains("bivouac") || type.contains("wilderness hut") ||
        name.contains("bivacco") || name.contains("bivouac")) return null;
    if (type.contains("rifugio") || type.contains("mountain lodge") || type.contains("alpine hut")) return GoTrailPoiStore.Category.HUT;
    if (type.contains("cascata") || type.contains("waterfall")) return GoTrailPoiStore.Category.WATERFALL;
    if (type.contains("parcheggio") || type.contains("parking") || type.contains("car park") ||
        type.contains("parking lot") || type.contains("parcheggio auto") ||
        name.contains("parcheggio") || name.contains("parking")) return GoTrailPoiStore.Category.PARKING;
    return null;
  }

  private void showCachedResults(@NonNull ArrayList<GoTrailPoiStore.Poi> items)
  {
    stopDotsAnimation();
    setProgressValue(100);
    mStatus.setText("Analisi completata usando le mappe locali.");
    mStepHut.setVisibility(View.VISIBLE);
    mStepFountain.setVisibility(View.GONE);
    mStepWaterfall.setVisibility(View.VISIBLE);
    mStepParking.setVisibility(View.VISIBLE);
    mStepViewpoint.setVisibility(View.GONE);
    mCount.setVisibility(View.GONE);
    if (mShowMap != null) mShowMap.setVisibility(View.VISIBLE);

    Collections.sort(items, Comparator.comparingDouble(a -> a.distanceKm));
    GoTrailPoiStore.set(mCenterLat, mCenterLon, items);
    showCompletedCategory(mStepHut, GoTrailPoiStore.Category.HUT, countCategory(items, GoTrailPoiStore.Category.HUT));
    showCompletedCategory(mStepFountain, GoTrailPoiStore.Category.FOUNTAIN, countCategory(items, GoTrailPoiStore.Category.FOUNTAIN));
    showCompletedCategory(mStepWaterfall, GoTrailPoiStore.Category.WATERFALL, countCategory(items, GoTrailPoiStore.Category.WATERFALL));
    showCompletedCategory(mStepParking, GoTrailPoiStore.Category.PARKING, countCategory(items, GoTrailPoiStore.Category.PARKING));
    showCompletedCategory(mStepViewpoint, GoTrailPoiStore.Category.VIEWPOINT, countCategory(items, GoTrailPoiStore.Category.VIEWPOINT));
    mResults.removeAllViews();
  }

  private void renderResultGroups(@NonNull ArrayList<GoTrailPoiStore.Poi> items)
  {
    mResults.removeAllViews();
    int huts = 0, fountains = 0, waterfalls = 0, parking = 0, viewpoints = 0;
    for (GoTrailPoiStore.Poi item : items)
    {
      if (item.category == GoTrailPoiStore.Category.HUT) huts++;
      else if (item.category == GoTrailPoiStore.Category.FOUNTAIN) fountains++;
      else if (item.category == GoTrailPoiStore.Category.WATERFALL) waterfalls++;
      else if (item.category == GoTrailPoiStore.Category.PARKING) parking++;
      else if (item.category == GoTrailPoiStore.Category.VIEWPOINT) viewpoints++;
    }
    addCategorySection("RIFUGI", GoTrailPoiStore.Category.HUT, huts, items);
    addCategorySection("CASCATE", GoTrailPoiStore.Category.WATERFALL, waterfalls, items);
    addCategorySection("PARCHEGGI", GoTrailPoiStore.Category.PARKING, parking, items);
  }

  private void finishAnalysis()
  {
    if (mActiveCategory != null) completeCategory(mActiveCategory);
    stopDotsAnimation();
    setProgressValue(100);
    mStatus.setText("Analisi completata usando le mappe locali.");
    mCount.setVisibility(View.GONE);
    if (mShowMap != null) mShowMap.setVisibility(View.VISIBLE);

    final ArrayList<GoTrailPoiStore.Poi> items = filterVisibleCategories(new ArrayList<>(mFound.values()));
    Collections.sort(items, Comparator.comparingDouble(a -> a.distanceKm));
    GoTrailPoiStore.set(mCenterLat, mCenterLon, items);
    // La cache conserva automaticamente le ultime 5 analisi; alla sesta elimina la piu' vecchia.
    GoTrailAnalysisCache.save(this, mCenterLat, mCenterLon, items);

    // v24: niente schermata riepilogo obbligatoria dopo la scansione.
    // Il riepilogo resta memorizzato e viene mostrato solo dal pulsante blu RISULTATI sulla mappa.
    mResults.removeAllViews();
  }

  private void addCategorySection(String title, GoTrailPoiStore.Category category, int count,
                                  ArrayList<GoTrailPoiStore.Poi> items)
  {
    final boolean hasResults = count > 0;
    final TextView header = text("", 18, Typeface.BOLD, Color.WHITE);
    setCategoryHeaderText(header, title, category, count, hasResults ? "▼" : "");
    header.setGravity(Gravity.CENTER_VERTICAL);
    header.setPadding(dp(14), dp(13), dp(14), dp(13));
    final GradientDrawable categoryBg = new GradientDrawable();
    categoryBg.setColor(Color.rgb(11, 95, 215));
    categoryBg.setCornerRadius(dp(22));
    header.setBackground(categoryBg);

    final LinearLayout section = new LinearLayout(this);
    section.setOrientation(LinearLayout.VERTICAL);
    section.setVisibility(View.GONE);

    if (category == GoTrailPoiStore.Category.FOUNTAIN)
    {
      final TextView fountainCount = text(count + (count == 1 ? " fontana trovata nella zona" : " fontane trovate nella zona"), 17, Typeface.NORMAL, Color.DKGRAY);
      fountainCount.setPadding(dp(16), dp(12), dp(16), dp(12));
      section.addView(fountainCount);
    }
    else
    {
      for (GoTrailPoiStore.Poi item : items)
        if (item.category == category)
          addResultRow(item, section);
    }

    if (hasResults)
    {
      header.setOnClickListener(v -> {
        final boolean open = section.getVisibility() == View.VISIBLE;
        section.setVisibility(open ? View.GONE : View.VISIBLE);
        setCategoryHeaderText(header, title, category, count, open ? "▼" : "▲");
      });
    }
    else
    {
      header.setClickable(false);
      header.setFocusable(false);
    }

    LinearLayout.LayoutParams hp = new LinearLayout.LayoutParams(-1, -2);
    hp.bottomMargin = dp(6);
    mResults.addView(header, hp);

    LinearLayout.LayoutParams sp = new LinearLayout.LayoutParams(-1, -2);
    sp.bottomMargin = dp(10);
    mResults.addView(section, sp);
  }

  private void setCategoryHeaderText(@NonNull TextView header, @NonNull String title,
                                     @NonNull GoTrailPoiStore.Category category, int count, @NonNull String arrow)
  {
    final String value = "●  " + title + "  (" + count + ")" + (TextUtils.isEmpty(arrow) ? "" : "   " + arrow);
    final SpannableString span = new SpannableString(value);
    final int dotColor = category == GoTrailPoiStore.Category.HUT ? Color.rgb(245, 145, 35)
                       : category == GoTrailPoiStore.Category.FOUNTAIN ? Color.rgb(30, 125, 230)
                       : category == GoTrailPoiStore.Category.WATERFALL ? Color.rgb(25, 190, 205)
                       : category == GoTrailPoiStore.Category.PARKING ? Color.rgb(70, 105, 180)
                       : Color.rgb(125, 90, 175);
    span.setSpan(new ForegroundColorSpan(dotColor), 0, 1, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE);
    header.setText(span);
  }

  private void addResultRow(GoTrailPoiStore.Poi item, LinearLayout parent)
  {
    final LinearLayout card = new LinearLayout(this);
    card.setOrientation(LinearLayout.VERTICAL); card.setPadding(dp(16), dp(14), dp(16), dp(14)); card.setBackgroundColor(Color.WHITE); card.setClickable(true); card.setFocusable(true);
    final String icon = categoryPrefix(item.category) + " ";
    card.addView(text(icon + item.title, 18, Typeface.BOLD, Color.rgb(25, 38, 55)));
    final TextView type = text(item.type, 14, Typeface.NORMAL, Color.DKGRAY); LinearLayout.LayoutParams tp = new LinearLayout.LayoutParams(-1, -2); tp.topMargin = dp(3); card.addView(type, tp);
    final TextView distance = text(String.format(Locale.ITALY, "%.1f km dal centro della zona", item.distanceKm), 15, Typeface.BOLD, Color.rgb(32, 168, 90));
    LinearLayout.LayoutParams dpv = new LinearLayout.LayoutParams(-1, -2); dpv.topMargin = dp(6); card.addView(distance, dpv);
    card.setOnClickListener(v -> {
      GoTrailPoiStore.clearShowRequest();
      openSelectedPoi(item.lat, item.lon, item.title);
    });
    LinearLayout.LayoutParams cardParams = new LinearLayout.LayoutParams(-1, -2); cardParams.bottomMargin = dp(10); parent.addView(card, cardParams);
  }

  private void openSelectedPoi(double lat, double lon, String title)
  {
    // v22: niente deep-link om:// per il singolo POI. Quel percorso riattivava
    // la place-page nativa e poteva lasciare la mappa in uno stato bloccato.
    final Intent mapIntent = new Intent(this, MwmActivity.class);
    mapIntent.putExtra("gotrail_focus_lat", lat);
    mapIntent.putExtra("gotrail_focus_lon", lon);
    mapIntent.putExtra("gotrail_focus_title", TextUtils.isEmpty(title) ? "Destinazione" : title);
    mapIntent.addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP | Intent.FLAG_ACTIVITY_SINGLE_TOP);
    startActivity(mapIntent);
    finish();
  }

  private void setActiveCategory(@NonNull GoTrailPoiStore.Category category)
  {
    if (mActiveCategory == category) return;
    if (mActiveCategory != null) completeCategory(mActiveCategory);
    mActiveCategory = category;
    mDotFrame = 0;
    mUiHandler.removeCallbacks(mDotsAnimator);
    updateActiveStep();
    mUiHandler.postDelayed(mDotsAnimator, 180);
  }

  private void configureStepView(@NonNull TextView view)
  {
    // Riga sempre alta una sola linea: niente numeri che vanno a capo o spostano la categoria sotto.
    view.setSingleLine(true);
    view.setGravity(Gravity.CENTER_VERTICAL);
    view.setIncludeFontPadding(true);
  }

  private SpannableString buildStepText(@NonNull String marker, @NonNull String label,
                                        boolean completed, int count, int activeDot)
  {
    // v24: durante la ricerca nessun numero. L'icona della categoria guida un
    // piccolo "treno" di 4..7 puntini e scorre verso destra, poi riparte.
    if (!completed)
    {
      // V26: il nome resta fermo; l'icona parte subito dopo e scorre verso destra.
      final int travel = Math.abs(activeDot % 16);
      final StringBuilder spaces = new StringBuilder();
      for (int i = 0; i < travel; i++) spaces.append("  ");
      final String object = "\uFFFC";
      final String raw = label + "  " + spaces + object;
      final SpannableString out = new SpannableString(raw);
      final int iconPos = raw.indexOf(object);
      final Drawable icon = getDrawable(categoryDrawable(mActiveCategory));
      if (icon != null && iconPos >= 0)
      {
        final int size = dp(24);
        icon.setBounds(0, 0, size, size);
        out.setSpan(new ImageSpan(icon, ImageSpan.ALIGN_BOTTOM),
                    iconPos, iconPos + 1, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE);
      }
      return out;
    }

    // Risultato: puntini verdi fissi, numero solo ora e icona fissa a destra.
    final int dotCount = count < 10 ? 7 : (count < 100 ? 6 : 5);
    final StringBuilder db = new StringBuilder();
    for (int i = 0; i < dotCount; i++) db.append('.');
    final String dots = db.toString();
    final String raw = marker + "  " + label + "  " + dots + "\t" + count;
    final SpannableString out = new SpannableString(raw);
    final int dotsStart = raw.indexOf(dots);
    final int dotsEnd = dotsStart + dots.length();
    out.setSpan(new RelativeSizeSpan(0.88f), dotsStart, dotsEnd, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE);
    out.setSpan(new ForegroundColorSpan(Color.rgb(32, 168, 90)), dotsStart, dotsEnd, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE);
    out.setSpan(new TabStopSpan.Standard(dp(205)), 0, raw.length(), Spanned.SPAN_EXCLUSIVE_EXCLUSIVE);
    return out;
  }

  private void updateActiveStep()
  {
    if (mActiveCategory == null) return;
    final TextView view = stepView(mActiveCategory);
    view.setCompoundDrawables(null, null, null, null);
    view.setText(buildStepText("", categoryLabel(mActiveCategory), false, 0, mDotFrame));
    view.setTextColor(Color.DKGRAY);
  }

  private void completeCategory(@NonNull GoTrailPoiStore.Category category)
  {
    showCompletedCategory(stepView(category), category, countCategory(category));
  }

  private void showCompletedCategory(@NonNull TextView view, @NonNull GoTrailPoiStore.Category category, int count)
  {
    final int green = Color.rgb(32, 168, 90);
    view.setText(buildStepText("✓", categoryLabel(category), true, count, -1));
    view.setTextColor(green);
    final Drawable icon = getDrawable(categoryDrawable(category));
    if (icon != null)
    {
      final int size = dp(28);
      icon.setBounds(0, 0, size, size);
      view.setCompoundDrawablePadding(dp(6));
      view.setCompoundDrawables(null, null, icon, null);
    }
  }

  private void stopDotsAnimation()
  {
    mUiHandler.removeCallbacks(mDotsAnimator);
    mActiveCategory = null;
  }

  private TextView stepView(@NonNull GoTrailPoiStore.Category category)
  {
    if (category == GoTrailPoiStore.Category.HUT) return mStepHut;
    if (category == GoTrailPoiStore.Category.FOUNTAIN) return mStepFountain;
    if (category == GoTrailPoiStore.Category.WATERFALL) return mStepWaterfall;
    if (category == GoTrailPoiStore.Category.PARKING) return mStepParking;
    return mStepViewpoint;
  }

  private String categoryLabel(@NonNull GoTrailPoiStore.Category category)
  {
    if (category == GoTrailPoiStore.Category.HUT) return "Rifugi";
    if (category == GoTrailPoiStore.Category.FOUNTAIN) return "Fontane";
    if (category == GoTrailPoiStore.Category.WATERFALL) return "Cascate";
    if (category == GoTrailPoiStore.Category.PARKING) return "Parcheggi";
    return "Panoramici";
  }

  private int categoryDrawable(@NonNull GoTrailPoiStore.Category category)
  {
    if (category == GoTrailPoiStore.Category.HUT) return R.drawable.gotrail_marker_hut;
    if (category == GoTrailPoiStore.Category.FOUNTAIN) return R.drawable.gotrail_marker_fountain;
    if (category == GoTrailPoiStore.Category.WATERFALL) return R.drawable.gotrail_marker_waterfall;
    if (category == GoTrailPoiStore.Category.PARKING) return R.drawable.gotrail_marker_parking;
    return R.drawable.gotrail_marker_viewpoint;
  }

  private String categoryFallback(@NonNull GoTrailPoiStore.Category category)
  {
    if (category == GoTrailPoiStore.Category.HUT) return "Rifugio";
    if (category == GoTrailPoiStore.Category.FOUNTAIN) return "Fontana";
    if (category == GoTrailPoiStore.Category.WATERFALL) return "Cascata";
    if (category == GoTrailPoiStore.Category.PARKING) return "Parcheggio";
    return "Punto panoramico";
  }

  private String categoryPrefix(@NonNull GoTrailPoiStore.Category category)
  {
    if (category == GoTrailPoiStore.Category.HUT) return "⛰";
    if (category == GoTrailPoiStore.Category.FOUNTAIN) return "💧";
    if (category == GoTrailPoiStore.Category.WATERFALL) return "🌊";
    if (category == GoTrailPoiStore.Category.PARKING) return "P";
    return "◉";
  }

  private String categoryPinStyle(@NonNull GoTrailPoiStore.Category category)
  {
    if (category == GoTrailPoiStore.Category.HUT) return "placemark-orange";
    if (category == GoTrailPoiStore.Category.FOUNTAIN) return "placemark-blue";
    if (category == GoTrailPoiStore.Category.WATERFALL) return "placemark-cyan";
    if (category == GoTrailPoiStore.Category.PARKING) return "placemark-blue";
    return "placemark-purple";
  }

  @NonNull
  private ArrayList<GoTrailPoiStore.Poi> filterVisibleCategories(@NonNull java.util.List<GoTrailPoiStore.Poi> source)
  {
    final ArrayList<GoTrailPoiStore.Poi> clean = new ArrayList<>();
    for (GoTrailPoiStore.Poi item : source)
    {
      if (item.category == GoTrailPoiStore.Category.HUT ||
          item.category == GoTrailPoiStore.Category.WATERFALL ||
          item.category == GoTrailPoiStore.Category.PARKING)
        clean.add(item);
    }
    return clean;
  }

  private int countCategory(@NonNull ArrayList<GoTrailPoiStore.Poi> items, @NonNull GoTrailPoiStore.Category category)
  {
    int count = 0;
    for (GoTrailPoiStore.Poi item : items) if (item.category == category) count++;
    return count;
  }

  private int countCategory(@NonNull GoTrailPoiStore.Category category)
  {
    int count = 0;
    for (GoTrailPoiStore.Poi item : mFound.values()) if (item.category == category) count++;
    return count;
  }

  private void setProgressValue(int value)
  {
    final int safe = Math.max(0, Math.min(100, value));
    mProgress.setProgress(safe);
    if (mProgressPercent != null) mProgressPercent.setText(safe + "%");
  }

  private void showError(String message) { setProgressValue(0); mStatus.setText(message); mStatus.setTextColor(Color.rgb(180, 35, 35)); }
  @Override protected void onDestroy() { stopDotsAnimation(); SearchEngine.INSTANCE.removeListener(this); super.onDestroy(); }

  private static double distanceKm(double lat1, double lon1, double lat2, double lon2)
  {
    final double earthKm = 6371.0088; final double dLat = Math.toRadians(lat2 - lat1); final double dLon = Math.toRadians(lon2 - lon1);
    final double a = Math.sin(dLat / 2) * Math.sin(dLat / 2) + Math.cos(Math.toRadians(lat1)) * Math.cos(Math.toRadians(lat2)) * Math.sin(dLon / 2) * Math.sin(dLon / 2);
    return earthKm * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  }
}
