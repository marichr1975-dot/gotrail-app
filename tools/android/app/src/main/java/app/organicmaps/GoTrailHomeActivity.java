package app.organicmaps;

import android.content.Intent;
import android.graphics.Typeface;
import android.os.Bundle;
import android.view.Gravity;
import android.view.View;
import android.widget.Button;
import android.widget.LinearLayout;
import android.widget.ScrollView;
import android.widget.TextView;
import android.widget.Toast;
import androidx.annotation.Nullable;
import androidx.appcompat.app.AppCompatActivity;

/**
 * GoTr-Ail XX1 experimental shell.
 * The Organic Maps core is intentionally left untouched: this Activity is only
 * a front door that hands control to the original SplashActivity.
 */
public class GoTrailHomeActivity extends AppCompatActivity
{
  @Override
  protected void onCreate(@Nullable Bundle savedInstanceState)
  {
    super.onCreate(savedInstanceState);
    setTitle("GoTr-Ail XX1");

    final int pad = dp(20);
    final LinearLayout root = new LinearLayout(this);
    root.setOrientation(LinearLayout.VERTICAL);
    root.setPadding(pad, pad, pad, pad);

    final TextView title = new TextView(this);
    title.setText("GoTr-Ail");
    title.setTextSize(32);
    title.setTypeface(Typeface.DEFAULT_BOLD);
    title.setGravity(Gravity.CENTER_HORIZONTAL);
    root.addView(title, matchWrap());

    final TextView subtitle = new TextView(this);
    subtitle.setText("XX1 • motore cartografico offline Organic Maps");
    subtitle.setTextSize(15);
    subtitle.setGravity(Gravity.CENTER_HORIZONTAL);
    subtitle.setPadding(0, dp(4), 0, dp(22));
    root.addView(subtitle, matchWrap());

    addMainButton(root, "CERCA / MAPPA OFFLINE", v -> openOrganicCore());
    addMainButton(root, "NAVIGAZIONE E ROUTING", v -> openOrganicCore());
    addMainButton(root, "MAPPE SCARICATE", v -> openOrganicCore());

    addSection(root, "FUNZIONI GOTr-Ail");
    addPrototypeButton(root, "🔭  ANALIZZO LA ZONA");
    addPrototypeButton(root, "🥾  PASSEGGIATE / SENTIERI");
    addPrototypeButton(root, "⌂  RIFUGI");
    addPrototypeButton(root, "💧  CASCATE / FONTANE");

    final TextView note = new TextView(this);
    note.setText("XX1 è una prova di integrazione: ricerca, mappe, routing e navigazione restano nel motore Organic Maps. Le funzioni GoTr-Ail verranno collegate nelle versioni successive.");
    note.setTextSize(13);
    note.setPadding(0, dp(22), 0, dp(10));
    root.addView(note, matchWrap());

    final ScrollView scroll = new ScrollView(this);
    scroll.addView(root);
    setContentView(scroll);
  }

  private void addMainButton(LinearLayout root, String text, View.OnClickListener listener)
  {
    final Button b = new Button(this);
    b.setText(text);
    b.setTextSize(16);
    b.setOnClickListener(listener);
    final LinearLayout.LayoutParams lp = matchWrap();
    lp.setMargins(0, dp(5), 0, dp(5));
    root.addView(b, lp);
  }

  private void addPrototypeButton(LinearLayout root, String text)
  {
    final Button b = new Button(this);
    b.setText(text);
    b.setTextSize(16);
    b.setOnClickListener(v -> Toast.makeText(this, "GoTr-Ail XX1: funzione da collegare al motore offline", Toast.LENGTH_SHORT).show());
    final LinearLayout.LayoutParams lp = matchWrap();
    lp.setMargins(0, dp(5), 0, dp(5));
    root.addView(b, lp);
  }

  private void addSection(LinearLayout root, String text)
  {
    final TextView v = new TextView(this);
    v.setText(text);
    v.setTextSize(18);
    v.setTypeface(Typeface.DEFAULT_BOLD);
    v.setPadding(0, dp(24), 0, dp(8));
    root.addView(v, matchWrap());
  }

  private void openOrganicCore()
  {
    startActivity(new Intent(this, SplashActivity.class));
  }

  private LinearLayout.LayoutParams matchWrap()
  {
    return new LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT);
  }

  private int dp(int value)
  {
    return Math.round(value * getResources().getDisplayMetrics().density);
  }
}
