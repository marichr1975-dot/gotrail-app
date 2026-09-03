package app.organicmaps;

import android.content.Intent;
import android.graphics.Color;
import android.graphics.Typeface;
import android.graphics.drawable.GradientDrawable;
import android.os.Bundle;
import android.view.Gravity;
import android.view.View;
import android.view.Window;
import android.view.WindowManager;
import android.widget.FrameLayout;
import android.widget.ImageView;
import android.widget.LinearLayout;
import android.widget.TextView;
import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.appcompat.app.AppCompatActivity;

/**
 * GoTr-Ail XX17 home shell.
 * UI derived from the GoTr-Ail V12.5 home while keeping the Organic Maps core intact.
 */
public class GoTrailHomeActivity extends AppCompatActivity
{
  private boolean mGoTrailSavedScreenOpen = false;

  private static final int BLUE = Color.rgb(11, 95, 215);
  private static final int GREEN = Color.rgb(32, 168, 90);
  private static final int DARK_TEXT = Color.rgb(23, 44, 67);

  @Override
  protected void onCreate(@Nullable Bundle savedInstanceState)
  {
    super.onCreate(savedInstanceState);
    setTitle("GoTr-Ail");

    final Window window = getWindow();
    window.setStatusBarColor(Color.TRANSPARENT);
    window.setNavigationBarColor(Color.rgb(7, 23, 37));
    window.setFlags(WindowManager.LayoutParams.FLAG_DRAWS_SYSTEM_BAR_BACKGROUNDS,
                    WindowManager.LayoutParams.FLAG_DRAWS_SYSTEM_BAR_BACKGROUNDS);

    final FrameLayout root = new FrameLayout(this);

    final ImageView background = new ImageView(this);
    background.setImageResource(R.drawable.gotrail_home_pelmo);
    background.setScaleType(ImageView.ScaleType.CENTER_CROP);
    root.addView(background, new FrameLayout.LayoutParams(
        FrameLayout.LayoutParams.MATCH_PARENT, FrameLayout.LayoutParams.MATCH_PARENT));

    final View shade = new View(this);
    final GradientDrawable shadeDrawable = new GradientDrawable(
        GradientDrawable.Orientation.TOP_BOTTOM,
        new int[] {0x22000818, 0x66000818, 0xF0071725});
    shade.setBackground(shadeDrawable);
    root.addView(shade, new FrameLayout.LayoutParams(
        FrameLayout.LayoutParams.MATCH_PARENT, FrameLayout.LayoutParams.MATCH_PARENT));

    final LinearLayout page = new LinearLayout(this);
    page.setOrientation(LinearLayout.VERTICAL);
    page.setPadding(dp(18), dp(24), dp(18), dp(18));
    final FrameLayout.LayoutParams pageLp = new FrameLayout.LayoutParams(
        FrameLayout.LayoutParams.MATCH_PARENT, FrameLayout.LayoutParams.MATCH_PARENT);
    root.addView(page, pageLp);

    addHeader(page);

    final View spacer = new View(this);
    page.addView(spacer, new LinearLayout.LayoutParams(1, 0, 1f));

    addSimpleAction(page, "INIZIA", GREEN, Color.WHITE,
                    v -> openOrganicCore("map"));
    addGap(page, 10);
    addSimpleAction(page, "MAPPE", BLUE, Color.WHITE,
                    v -> openOrganicCore("maps"));
    addGap(page, 10);
    addSimpleAction(page, "PIANIFICA", Color.WHITE, DARK_TEXT,
                    v -> openOrganicCore("saved"));

    setContentView(root);
  }

  private void showSavedScreen(FrameLayout root)
  {
    mGoTrailSavedScreenOpen = true;
    final LinearLayout page = new LinearLayout(this);
    page.setOrientation(LinearLayout.VERTICAL);
    page.setPadding(dp(18), dp(28), dp(18), dp(18));
    page.setBackgroundColor(Color.rgb(247, 249, 252));

    final LinearLayout titleRow = new LinearLayout(this);
    titleRow.setOrientation(LinearLayout.HORIZONTAL);
    titleRow.setGravity(Gravity.CENTER_VERTICAL);

    final TextView back = new TextView(this);
    back.setText("‹");
    back.setTextSize(30);
    back.setTextColor(BLUE);
    back.setTypeface(Typeface.DEFAULT, Typeface.BOLD);
    back.setGravity(Gravity.CENTER);
    back.setOnClickListener(v -> { mGoTrailSavedScreenOpen = false; recreate(); });
    titleRow.addView(back, new LinearLayout.LayoutParams(dp(42), dp(52)));

    final TextView title = new TextView(this);
    title.setText("Percorsi Salvati");
    title.setTextSize(26);
    title.setTextColor(DARK_TEXT);
    title.setTypeface(Typeface.DEFAULT, Typeface.BOLD);
    title.setGravity(Gravity.CENTER_VERTICAL);
    titleRow.addView(title, new LinearLayout.LayoutParams(0, dp(52), 1f));

    page.addView(titleRow, new LinearLayout.LayoutParams(
        LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT));

    addSimpleAction(page, "PERCORSI", Color.WHITE, DARK_TEXT, v -> openOrganicCore("saved"));
    addGap(page, 16);

    final TextView section = new TextView(this);
    section.setText("PUNTI SALVATI");
    section.setTextSize(16);
    section.setTextColor(DARK_TEXT);
    section.setTypeface(Typeface.DEFAULT, Typeface.BOLD);
    section.setPadding(dp(4), dp(4), 0, dp(10));
    page.addView(section);

    final java.util.Set<String> saved = getSharedPreferences("gotrail_saved_points", MODE_PRIVATE)
        .getStringSet("points", java.util.Collections.emptySet());
    if (saved.isEmpty())
    {
      final TextView empty = new TextView(this);
      empty.setText("Nessun punto salvato");
      empty.setTextSize(15);
      empty.setTextColor(Color.rgb(100, 110, 120));
      empty.setPadding(dp(4), dp(10), 0, 0);
      page.addView(empty);
    }
    else
    {
      for (String item : saved)
      {
        final String[] parts = item.split("\\|", 4);
        final LinearLayout row = new LinearLayout(this);
        row.setOrientation(LinearLayout.HORIZONTAL);
        row.setGravity(Gravity.CENTER_VERTICAL);
        row.setPadding(dp(16), 0, dp(8), 0);
        final GradientDrawable bg = new GradientDrawable();
        bg.setColor(Color.WHITE);
        bg.setCornerRadius(dp(14));
        row.setBackground(bg);

        final String category = parts.length > 3 ? parts[3] : "";
        final int pointIcon = savedPointDrawable(category);
        if (pointIcon != 0)
        {
          final ImageView icon = new ImageView(this);
          icon.setImageResource(pointIcon);
          icon.setScaleType(ImageView.ScaleType.CENTER_INSIDE);
          final LinearLayout.LayoutParams iconLp = new LinearLayout.LayoutParams(dp(36), dp(36));
          iconLp.rightMargin = dp(10);
          row.addView(icon, iconLp);
        }

        final TextView pointName = new TextView(this);
        pointName.setText(parts.length > 0 ? parts[0] : "Punto salvato");
        pointName.setTextSize(16);
        pointName.setTextColor(DARK_TEXT);
        pointName.setTypeface(Typeface.DEFAULT, Typeface.BOLD);
        pointName.setGravity(Gravity.CENTER_VERTICAL);
        row.addView(pointName, new LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.MATCH_PARENT, 1f));

        final TextView trash = new TextView(this);
        trash.setText("🗑");
        trash.setTextSize(20);
        trash.setGravity(Gravity.CENTER);
        trash.setContentDescription("Elimina punto salvato");
        trash.setOnClickListener(v ->
        {
          final java.util.LinkedHashSet<String> updated = new java.util.LinkedHashSet<>(
              getSharedPreferences("gotrail_saved_points", MODE_PRIVATE)
                  .getStringSet("points", java.util.Collections.emptySet()));
          updated.remove(item);
          getSharedPreferences("gotrail_saved_points", MODE_PRIVATE)
              .edit().putStringSet("points", updated).apply();
          showSavedScreen(root);
        });
        row.addView(trash, new LinearLayout.LayoutParams(dp(50), LinearLayout.LayoutParams.MATCH_PARENT));

        final LinearLayout.LayoutParams lp = new LinearLayout.LayoutParams(
            LinearLayout.LayoutParams.MATCH_PARENT, dp(58));
        lp.bottomMargin = dp(8);
        page.addView(row, lp);
      }
    }

    root.removeAllViews();
    root.addView(page, new FrameLayout.LayoutParams(FrameLayout.LayoutParams.MATCH_PARENT, FrameLayout.LayoutParams.MATCH_PARENT));
  }

  private void addHeader(LinearLayout page)
  {
    final LinearLayout header = new LinearLayout(this);
    header.setOrientation(LinearLayout.VERTICAL);

    final LinearLayout titleRow = new LinearLayout(this);
    titleRow.setOrientation(LinearLayout.HORIZONTAL);
    titleRow.setGravity(Gravity.CENTER_VERTICAL);

    final TextView title = new TextView(this);
    title.setText("GoTr-Ail");
    title.setTextColor(Color.WHITE);
    title.setTextSize(30);
    title.setTypeface(Typeface.DEFAULT, Typeface.BOLD);
    titleRow.addView(title, new LinearLayout.LayoutParams(
        0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f));

    final TextView version = new TextView(this);
    version.setText("v.30.5");
    version.setTextColor(Color.WHITE);
    version.setTextSize(14);
    version.setTypeface(Typeface.DEFAULT, Typeface.BOLD);
    version.setGravity(Gravity.CENTER_VERTICAL | Gravity.END);
    titleRow.addView(version, wrapWrap());

    header.addView(titleRow, new LinearLayout.LayoutParams(
        LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT));

    final TextView subtitle = new TextView(this);
    subtitle.setText("Il tuo accompagnatore nei sentieri");
    subtitle.setTextColor(Color.rgb(234, 244, 255));
    subtitle.setTextSize(13);
    subtitle.setTypeface(Typeface.DEFAULT, Typeface.BOLD);
    LinearLayout.LayoutParams subtitleLp = wrapWrap();
    subtitleLp.topMargin = dp(4);
    header.addView(subtitle, subtitleLp);

    page.addView(header, new LinearLayout.LayoutParams(
        LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT));
  }

  private void addSimpleAction(LinearLayout page, String title, int backgroundColor,
                               int textColor, View.OnClickListener click)
  {
    final TextView button = new TextView(this);
    button.setText(title);
    button.setTextColor(textColor);
    button.setTextSize(16);
    button.setTypeface(Typeface.DEFAULT, Typeface.BOLD);
    button.setGravity(Gravity.CENTER);
    button.setBackground(roundRect(backgroundColor, 17,
                                   backgroundColor == Color.WHITE ? Color.WHITE : backgroundColor,
                                   backgroundColor == Color.WHITE ? 1 : 0));
    button.setClickable(true);
    button.setFocusable(true);
    button.setOnClickListener(click);

    page.addView(button, new LinearLayout.LayoutParams(
        LinearLayout.LayoutParams.MATCH_PARENT, dp(58)));
  }

  private void openOrganicPlanner()
  {
    final Intent intent = new Intent(this, MwmActivity.class);
    intent.putExtra(MwmActivity.EXTRA_GOTRAIL_OPEN_PLANNER, true);
    intent.addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP | Intent.FLAG_ACTIVITY_SINGLE_TOP);
    startActivity(intent);
  }

  private void openOrganicCore(String destination)
  {
    final Intent intent = new Intent(this, SplashActivity.class);
    intent.putExtra(SplashActivity.EXTRA_GOTRAIL_DESTINATION, destination);
    startActivity(intent);
  }

  @Override
  public void onBackPressed()
  {
    if (mGoTrailSavedScreenOpen)
    {
      mGoTrailSavedScreenOpen = false;
      recreate();
      return;
    }

    new androidx.appcompat.app.AlertDialog.Builder(this)
        .setTitle("GoTr-Ail")
        .setMessage("Vuoi uscire davvero?")
        .setNegativeButton("NO", null)
        .setPositiveButton("SÌ", (dialog, which) -> finishAffinity())
        .show();
  }

  private int savedPointDrawable(@NonNull String category)
  {
    if ("HUT".equals(category)) return R.drawable.gotrail_marker_hut;
    if ("FOUNTAIN".equals(category)) return R.drawable.gotrail_marker_fountain;
    if ("WATERFALL".equals(category)) return R.drawable.gotrail_marker_waterfall;
    if ("PARKING".equals(category)) return R.drawable.gotrail_marker_parking;
    if ("VIEWPOINT".equals(category)) return R.drawable.gotrail_marker_viewpoint;
    return 0;
  }

  private GradientDrawable roundRect(int fill, int radiusDp, int strokeColor, int strokeDp)
  {
    final GradientDrawable d = new GradientDrawable();
    d.setColor(fill);
    d.setCornerRadius(dp(radiusDp));
    if (strokeDp > 0)
      d.setStroke(dp(strokeDp), strokeColor);
    return d;
  }

  private void addGap(LinearLayout root, int heightDp)
  {
    final View gap = new View(this);
    root.addView(gap, new LinearLayout.LayoutParams(1, dp(heightDp)));
  }

  private LinearLayout.LayoutParams wrapWrap()
  {
    return new LinearLayout.LayoutParams(
        LinearLayout.LayoutParams.WRAP_CONTENT, LinearLayout.LayoutParams.WRAP_CONTENT);
  }

  private int dp(int value)
  {
    return Math.round(value * getResources().getDisplayMetrics().density);
  }
}
