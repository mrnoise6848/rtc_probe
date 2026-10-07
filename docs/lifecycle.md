# Lifecycle and cleanup

A background/hidden/detached app ends its session; foreground requires a new contextual Start action. Inactive alone does not end it because OS permission dialogs cause inactive transitions. Dashboard disposal also ends the session. Detail routes reuse the same controller and do not own resources.

Start/end are serialized. A generation token rejects asynchronous permission/setup results after cancellation; any returned capture/session is cleaned. State callbacks retain their latest value so transitions during negotiation are not falsely replaced by an idle UI. Sampling ignores results from old sessions. Durations/delta intervals use a monotonic stopwatch.

Setup failure closes partially created peers, capture tracks and streams. End cancels sampling/subscriptions, closes data channel, capture, peers and broadcast streams. Restoring permissions in system settings takes effect on the next session. No background audio entitlement is used.
