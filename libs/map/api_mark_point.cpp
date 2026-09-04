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

  // V30.8.7:
  // usiamo simboli bookmark NATIVI di Organic Maps, cioè simboli già previsti
  // per UserMark e quindi compatibili con lo stesso renderer di ApiMarkPoint.
  // Tutti gli altri deep-link/API mark conservano il comportamento originale.
  std::string symbolName = "coloredmark-default-s";

  if (m_id == "GOTRAIL_HUT")
    symbolName = "alpine_hut-m";
  else if (m_id == "GOTRAIL_WATERFALL")
    symbolName = "bookmark-water-m";
  else if (m_id == "GOTRAIL_PARKING")
    symbolName = "bookmark-parking-m";
  else if (m_id == "GOTRAIL_INTEREST")
    symbolName = "bookmark-art-m";

  symbol->insert(std::make_pair(1 /* zoomLevel */, symbolName));
  return symbol;
}

df::ColorConstant ApiMarkPoint::GetColorConstant() const
{
  // GoTr-Ail: the hut icon already contains its own brown circle and house.
  // Returning the API style color here adds the generic placemark layer
  // (the triangle/pin effect). Disable that layer only for huts.
  if (m_id == "GOTRAIL_HUT")
    return {};

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
