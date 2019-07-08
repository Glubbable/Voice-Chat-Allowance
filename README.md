# Voice Chat Allowance
This plugin is intended to provide some form of automatic moderation to the amount of time users spend on the mic. Originally written in mind to mitigate prolonged micspam but this also helps with those that forget to breath between sentences.

# Requirements
### Voice Announce EX
  - Original: https://github.com/Franc1sco/VoiceAnnounceEX
  - Lite: https://github.com/Glubbable/VoiceAnnounceEX/tree/lite
  
Strongly recommend the lite version provided. This plugin only depends on the native VAEX provides. The Forwards are kind of moot and are a waste of resources to be fired every frame for a clients transmit.

### Sourcemod 1.9+
  - Site: https://www.sourcemod.net/

# ConVars
### sm_voice_allowance_enable
  - 0 to disable, 1 to enable. Default to 1.
  - Determins if players voice chat time should be regulated.

### sm_voice_allowance_admin_immune
  - 0 to disable, 1 to enable. Default to 1.
  - Determins if voice chat time should apply to Admins.

### sm_voice_allowance_time
  - Default to 12 seconds, min allowed 12 seconds, no max.
  - Determins the default starting time for clients.

### sm_voice_allowance_max_time
  - Default to 60 seconds, min allowed 30 seconds, no max.
  - Determins the max amount of allowance a client can have.

