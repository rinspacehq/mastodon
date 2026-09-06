# Rinspace navigation fonts

`rinspace.scss` and its WOFF2 shards are an exact application copy of the
pinned `ui/public/fonts/library/rinspace-core-fonts.css` asset set in the
private Rinspace product repository. The source set is generated from Google
Fonts and contains IBM Plex Mono, IBM Plex Sans, and Newsreader font faces.
Their SIL Open Font License 1.1 text is retained in `RINSPACE_OFL.txt`.

The inner-world shell uses the same interface, navigation and editorial
families as the outer product. IBM Plex Sans replaces the application-only
Roboto alias after browser comparison showed no material card reflow while
removing three large legacy font downloads. When the private font snapshot
changes, review the visual delta and update the stylesheet and shards together
rather than downloading floating assets during the Mastodon build.
