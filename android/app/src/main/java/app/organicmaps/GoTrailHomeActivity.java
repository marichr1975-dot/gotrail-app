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
import androidx.annotation.Nullable;
import androidx.appcompat.app.AppCompatActivity;

/**
 * GoTr-Ail XX17 home shell.
 * UI derived from the GoTr-Ail V12.5 home while keeping the Organic Maps core intact.
 */
public class GoTrailHomeActivity extends AppCompatActivity
{
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

    addPrimaryAction(page, "▶", "INIZIA", "Apri la mappa dalla tua posizione", GREEN,
                     v -> openOrganicCore("map"));
    addGap(page, 8);
    addPrimaryAction(page, "▣", "MAPPE", "Gestisci le mappe offline", BLUE,
                     v -> openOrganicCore("maps"));
    addGap(page, 8);
    addSavedRoutesAction(page);

    setContentView(root);
  }

  private void addHeader(LinearLayout page)
  {
    final LinearLayout row = new LinearLayout(this);
    row.setOrientation(LinearLayout.HORIZONTAL);
    row.setGravity(Gravity.CENTER_VERTICAL);

    final TextView logo = new TextView(this);
    logo.setText("▲");
    logo.setTextColor(BLUE);
    logo.setTextSize(25);
    logo.setTypeface(Typeface.DEFAULT_BOLD);
    logo.setGravity(Gravity.CENTER);
    logo.setBackground(roundRect(Color.argb(245, 255, 255, 255), 15, 0, 0));
    row.addView(logo, new LinearLayout.LayoutParams(dp(50), dp(50)));

    final LinearLayout titles = new LinearLayout(this);
    titles.setOrientation(LinearLayout.VERTICAL);
    titles.setPadding(dp(10), 0, 0, 0);

    final TextView title = new TextView(this);
    title.setText("GoTr-Ail");
    title.setTextColor(Color.WHITE);
    title.setTextSize(28);
    title.setTypeface(Typeface.DEFAULT, Typeface.BOLD);
    titles.addView(title, wrapWrap());

    final TextView subtitle = new TextView(this);
    subtitle.setText("Il tuo accompagnatore nei sentieri");
    subtitle.setTextColor(Color.rgb(234, 244, 255));
    subtitle.setTextSize(12);
    subtitle.setTypeface(Typeface.DEFAULT, Typeface.BOLD);
    titles.addView(subtitle, wrapWrap());

    row.addView(titles, new LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f));

    final TextView version = new TextView(this);
    version.setText("v.25");
    version.setTextColor(Color.WHITE);
    version.setTextSize(15);
    version.setTypeface(Typeface.DEFAULT, Typeface.BOLD);
    version.setGravity(Gravity.CENTER_VERTICAL | Gravity.END);
    row.addView(version, wrapWrap());

    page.addView(row, new LinearLayout.LayoutParams(
        LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT));
  }

  private void addPrimaryAction(LinearLayout page, String icon, String title, String subtitle,
                                int color, View.OnClickListener click)
  {
    final LinearLayout card = new LinearLayout(this);
    card.setOrientation(LinearLayout.HORIZONTAL);
    card.setGravity(Gravity.CENTER_VERTICAL);
    card.setPadding(dp(13), 0, dp(12), 0);
    card.setBackground(roundRect(color, 17, 0, 0));
    card.setClickable(true);
    card.setFocusable(true);
    card.setOnClickListener(click);

    final TextView iconView = new TextView(this);
    iconView.setText(icon);
    iconView.setTextColor(Color.WHITE);
    iconView.setTextSize(20);
    iconView.setGravity(Gravity.CENTER);
    iconView.setTypeface(Typeface.DEFAULT_BOLD);
    iconView.setBackground(roundRect(0x33FFFFFF, 50, 0, 0));
    card.addView(iconView, new LinearLayout.LayoutParams(dp(39), dp(39)));

    final LinearLayout labels = new LinearLayout(this);
    labels.setOrientation(LinearLayout.VERTICAL);
    labels.setGravity(Gravity.CENTER_VERTICAL);
    labels.setPadding(dp(11), 0, dp(6), 0);

    final TextView t = new TextView(this);
    t.setText(title);
    t.setTextColor(Color.WHITE);
    t.setTextSize(16);
    t.setTypeface(Typeface.DEFAULT, Typeface.BOLD);
    labels.addView(t, wrapWrap());

    final TextView s = new TextView(this);
    s.setText(subtitle);
    s.setSingleLine(true);
    s.setTextColor(Color.WHITE);
    s.setTextSize(11);
    s.setTypeface(Typeface.DEFAULT, Typeface.BOLD);
    labels.addView(s, wrapWrap());

    card.addView(labels, new LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.MATCH_PARENT, 1f));

    final TextView arrow = new TextView(this);
    arrow.setText("›");
    arrow.setTextColor(Color.WHITE);
    arrow.setTextSize(30);
    arrow.setGravity(Gravity.CENTER);
    card.addView(arrow, new LinearLayout.LayoutParams(dp(28), LinearLayout.LayoutParams.MATCH_PARENT));

    page.addView(card, new LinearLayout.LayoutParams(
        LinearLayout.LayoutParams.MATCH_PARENT, dp(64)));
  }

  private void addSavedRoutesAction(LinearLayout page)
  {
    final TextView saved = new TextView(this);
    saved.setText("★   PERCORSI SALVATI");
    saved.setTextColor(DARK_TEXT);
    saved.setTextSize(13);
    saved.setTypeface(Typeface.DEFAULT, Typeface.BOLD);
    saved.setGravity(Gravity.CENTER);
    saved.setBackground(roundRect(Color.WHITE, 15, Color.WHITE, 1));
    saved.setClickable(true);
    saved.setFocusable(true);
    saved.setOnClickListener(v -> openOrganicCore("saved"));
    page.addView(saved, new LinearLayout.LayoutParams(
        LinearLayout.LayoutParams.MATCH_PARENT, dp(44)));
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
    new androidx.appcompat.app.AlertDialog.Builder(this)
        .setTitle("GoTr-Ail")
        .setMessage("Vuoi uscire davvero?")
        .setNegativeButton("NO", null)
        .setPositiveButton("SÌ", (dialog, which) -> finishAffinity())
        .show();
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
