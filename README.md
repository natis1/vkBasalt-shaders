# vkBasalt-shaders

Some shaders I have made in my spare time for vkBasalt/ReShade

### dayinsect

Simulates depth of field for any creature with compound eyes.
They have a fixed focal length and a minimum amount that stuff can get out of focus
and this out of focusness is done as pixelation because each lens is, at worst, always capable of getting at least one pixel.

For maximum realism, set the distance values so that everything at the distance you most often stare is in focus, everything
closer than that distance is nearly in focus, and everything far away is pixelated
