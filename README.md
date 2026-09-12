# APB Based GPIO Controller Design
## Introduction to GPIO
At the very basic level, GPIO refers to a set of pins on a computer's motherboard or an add-on card. These pins can send and/or receive electrical signals. However
it is worth noting that, these pins are meant for any specific purpose, hence the term "General Purpose".
A GPIO Module provides an SoC or a processor to interact with external hardware world. Some such examples can be like reading a tactile button or a switch, driving
an LED, or maybe controlling simple digital signals.
The following figure shows the internal circuitry of a GPIO Pin Control: -

<img width="626" height="452" alt="image" src="https://github.com/user-attachments/assets/d4aa294b-a95c-48ff-bc86-9bc6d4d3499a" />

## Project Design
This project is aimed to design an APB based GPIO controller. Any high-speed processor cannot directly communicate with a peripheral device connected externally (since processors run at giga-hertz frequency, while external peripherals run from kilo-hertz to mega-hertz). In order to communicate, the processor uses something called, AXI-to-APB bridge. This bridge converts the AXI signals to APB signals. We will use these APB Signals to drive a GPIO controller.
To do so, we need to design our own GPIO Port Controller. The Port Controller will communicate with the external pins and transfer messages between the AXI-to-APB bridge and the hardware external pins.
The intended design will have two sub-blocks: - the APB Bus Interface and the GPIO Port Interface. These two sub-blocks will be wrapped inside a topmodule wrapper (the usual standard). The GPIO Port Interface will be connected to the GPIO 
