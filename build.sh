#!/bin/bash

~/sm/addons/sourcemod/scripting/spcomp -i ~/sm/addons/sourcemod/scripting/include $PWD/src/sourcemod-matchstatus-discord.sp
mv sourcemod-matchstatus-discord.smx ./bin
