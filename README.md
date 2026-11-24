# EOG-Controlled Game: Playing with Your Eyes

A human–machine interface that lets a person control a computer game using only eye movements. Built for the Brain–Machine Interfaces course at Universidad Carlos III de Madrid (2026).

Group project by Ignacio Hernández, Mauro Vicente and Álvaro.

## How it works

1. **Signal.** The eye acts as an electrical dipole: the front is positive relative to the back. When the eyes move, the voltage measured by electrodes placed around them changes. This signal is the electrooculogram (EOG).
2. **Acquisition.** Surface electrodes around the eyes pick up the EOG, and an Arduino digitises the signal and streams it to the computer.
3. **Processing (MATLAB).** The signal is filtered, and eye movements are detected and classified into commands.
4. **Control.** Each detected eye movement is mapped to an action in the game, so the player controls it without using their hands.

## Why it matters

The same principle is used in assistive technology for people who cannot use their hands, such as people with spinal cord injury or ALS, to control computers, communication devices or wheelchairs.

## Repository structure

```
arduino/        Arduino code for signal acquisition
matlab/         Signal processing, movement detection and the game
report/         Project report
```

## My contribution

I worked on the system with my teammates, from electrode placement and signal acquisition to controlling the game.

## Notes

This is a teaching project, not a medical device.
