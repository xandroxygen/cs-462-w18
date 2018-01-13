# Hearing Aid Exercise

Xander Moffatt

note: I added the class today (Jan 12), and I'm not sure if I needed to find a partner for this? or if those are directions for the IRL section.

1. What features/properties make hearing aids a distributed system?

* both devices need to:
  * control volume separately
  * make decisions on how to amplify sound
  * communicate with each other
* communication with phone app for parameter adjustment

2. Are they decentralized or centralized?

* if the system only included the hearing aids, I would say decentralized. They would have to rely on each other, and both control the system.
* however, the addition of a phone app to control the devices makes it a centralized system. The aids can rely on the app for parameters and commands.

3. What role might latency play in their design?

* there shouldn't be much latency between the app and devices, since they are always close by. Though they are not connected, wireless signals shouldn't be too slow.
* too much latency could mean a discrepancy, example: between the app issuing a "volume down" command and the devices complying, which could potentially harm the user if the sound was too loud.
