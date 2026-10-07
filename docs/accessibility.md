# Accessibility

Controls have text labels/tooltips and Material tap targets. Quality/connection are always named in text so color is supplementary. Metrics expose named values through semantics, explicitly including Not available. Metric cards wrap into one/two/three columns based on width and text scale; screens scroll rather than clipping large text. Theme follows system light/dark preference.

Chart selection changes the metric label; every retained sample is inspectable as text in Metric history. Details explain application echo RTT versus transport RTT. Findings provide evidence and possible impact, without requiring users to interpret raw protocol logs.

TalkBack/VoiceOver and very large font behavior require a physical-device check before claiming full accessibility validation.
