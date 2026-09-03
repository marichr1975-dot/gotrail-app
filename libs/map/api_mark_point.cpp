#include "map/api_mark_point.hpp"

#include <map>

namespace style
{
std::map<std::string_view, df::ColorConstant> kStyleToColor = {
    {"placemark-red", "BookmarkRed"},
    {"placemark-blue", "BookmarkBlue"},
    {"placemark-purple", "BookmarkPurple"},
    {"placemark-yellow", "BookmarkYellow"},
    {"placemark-pink", "BookmarkPink"},
    {"placemark-brown", "BookmarkBrown"},
    {"placemark-green", "BookmarkGreen"},
    {"placemark-orange", "BookmarkOrange"},
    {"placemark-deeppurple", "BookmarkDeepPurple"},
    {"placemark-lightblue", "BookmarkLightBlue"},
    {"placemark-cyan", "BookmarkCyan"},
    {"placemark-teal", "BookmarkTeal"},
    {"placemark-lime", "BookmarkLime"},
    {"placemark-deeporange", "BookmarkDeepOrange"},
    {"placemark-gray", "BookmarkGray"},
    {"placemark-bluegray", "BookmarkBlueGray"},
};

df::ColorConstant GetSupportedStyle(std::string_view style)
{
  auto const it = kStyleToColor.find(style);
  if (it == kStyleToColor.cend())
    return "BookmarkGreen";
  return it->second;
}
}  // namespace style

ApiMarkPoint::ApiMarkPoint(m2::PointD const & ptOrg) : UserMark(ptOrg, UserMark::Type::API) {}

drape_ptr<df::UserPointMark::SymbolNameZoomInfo> ApiMarkPoint::GetSymbolNames() const
{
  auto symbol = make_unique_dp<SymbolNameZoomInfo>();

  // GoTr-Ail: preserve the native API mark coordinates/renderer, changing only
  // the atlas symbol used for the three analysis categories.
  std::string_view symbolName = "coloredmark-default-s";
  if (m_style == "BookmarkOrange")
    symbolName = "alpine_hut-m";       // rifugio: simbolo nativo caldo, grande
  else if (m_style == "BookmarkBlue")
    symbolName = "drinking-water-s";   // fontana: blu, piu piccola
  else if (m_style == "BookmarkCyan")
    symbolName = "waterfall-s";        // cascata: azzurra, piu piccola

  symbol->insert(std::make_pair(1 /* zoomLevel */, std::string(symbolName)));
  return symbol;
}

df::ColorConstant ApiMarkPoint::GetColorConstant() const
{
  return m_style;
}

void ApiMarkPoint::SetName(std::string const & name)
{
  SetDirty();
  m_name = name;
}

void ApiMarkPoint::SetApiID(std::string const & id)
{
  SetDirty();
  m_id = id;
}

void ApiMarkPoint::SetStyle(df::ColorConstant style)
{
  SetDirty();
  m_style = style;
}
