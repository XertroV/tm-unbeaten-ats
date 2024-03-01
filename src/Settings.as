
#if DEPENDENCY_MANIAEXCHANGE
[Setting category="Integrations" name="Open TMX Links in the ManiaExchange plugin?"]
bool S_OpenTmxInManiaExchange = true;
#else
bool S_OpenTmxInManiaExchange = false;
#endif


[Setting category="Colors" name="Played Map Button Hue" min=0.0 max=1.0 description="0 = red, 0.14 = yellow, .33 = green, .67 = blue, .83 = purple"]
float S_PlayedMapColor = 0.5;
