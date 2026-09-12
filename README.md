# APB Based GPIO Controller Design
## Introduction to GPIO
At the very basic level, GPIO refers to a set of pins on a computer's motherboard or an add-on card. These pins can send and/or receive electrical signals. However
it is worth noting that, these pins are meant for any specific purpose, hence the term "General Purpose".
A GPIO Module provides an SoC or a processor to interact with external hardware world. Some such examples can be like reading a tactile button or a switch, driving
an LED, or maybe controlling simple digital signals.
The following figure shows the internal circuitry of a GPIO Pin Control: -
<figure>
  <img width="626" height="452" alt="image" src="https://github.com/user-attachments/assets/d4aa294b-a95c-48ff-bc86-9bc6d4d3499a" />
  <br><br>
  <figcaption>
    GPIO Port Controller
  </figcaption>
</figure>

## Project Design
This project is aimed to design an APB based GPIO controller. Any high-speed processor cannot directly communicate with a peripheral device connected externally (since processors run at giga-hertz frequency, while external peripherals run from kilo-hertz to mega-hertz). In order to communicate, the processor uses something called, AXI-to-APB bridge. This bridge converts the AXI signals to APB signals. We will use these APB Signals to drive a GPIO controller.
To do so, we need to design our own GPIO Port Controller. The Port Controller will communicate with the external pins and transfer messages between the AXI-to-APB bridge and the hardware external pins.
The intended design will have two sub-blocks: - the APB Bus Interface and the GPIO Port Interface. These two sub-blocks will be wrapped inside a topmodule wrapper (the usual standard). The GPIO Port Interface will be connected to the external GPIO Pins. A top-level architecture of our intended design is shown below: -
<figure>
  <img width="620" height="182" alt="Schematic Architecture" src="https://github.com/user-attachments/assets/8e97b4e4-6698-4759-be91-6463eff08303" />
  <br><br>
  <figcaption>
    Top-Level Architecture
  </figcaption>
</figure>
<br>
The GPIO Controller has registers in it. These registers are configurable in nature. It is by configuring these registers that we can control the pins (and subsequently the external connected peripheral device). Each such register will have a unique address.

### The Port Interface
The GPIO port interface communicates with the external GPIO pins. There are various ports associated with this module, like the **gpio_dir**, **gpio_data_in**, **gpio_data_out** and **xpins**. The __gpio_dir__ is a 32-bit input bus, which carries the data for the direction of each port. There are 32 GPIO pins (configurable in nature), and each port is bidirectional in nature. The direction of each port is determined by the value present in this bus.
__gpio_data_out__ is a 32-bit bus which is arriving from the APB Interface and carries the data that the master wants to send to the external device. __gpio_data_in__ is another 32-bit bus which is coming from the xpins, and contains the data sent by the external peripheral device. The master will read this data. __xpinx__ are the actual pins/ports which are connected to the external pins. Whatever data the xpins have, is seperated into two parts. This seperation depends upon the direction of each pin. When the direction value is 1 (high), it indicates that the master wants to write some data. Accordingly, the data present on the __gpio_data_out__ bus is transferred to the xpins. Read logic is combinational, so whatever data is present in the xpins, is always available in the __gpio_data_in__ bus. It can be correct to infer that the **xpins** bus and **gpio_data_in** bus are shorted. One must be careful about the naming done here.
**gpio_data_out** is the data which the master wants to write on the peripheral. Hence, this data comes from the APB Bus Interface (which is connected to master).
**gpio_data_in** is the data which is present in the xpins. These two buses are shorted - thus whatever data is present in the xpins, is always available to the master. Using the **gpio_dir** bus, master can either read the data or write the data.

### The APB Controller
The APB Controller is the heart of the design. The APB Controller contains the various configurable registers. The controller operates on three different FSM states - IDLE, SETUP, ACCESS. This is analogous to the FSM states of the APB Protocol. The APB Controller includes all the signals of the APB protocol. Additionally, it also has the **gpio_data_out**, **gpio_data_in**, **gpio_data_dir** pins, which are to be interfaced with the previously discussed Port Interface. These three pins serve the same purpose as discussed earlier.
Two 32-bit registers are declared, and three addresses are chosen for them - **0x00**, **0x04**, **0x08**. These addresses are used when the master (SoC) will write some data to the APB interface. The APB interface will forward the data of the master. 0x00 is the address for the dataout register, 0x04 is the address for the direction register and 0x08 is the address for the datain register. All data (be it the data to be written out to the slave, or the data for the direction of the xpins) is carried by the PWDATA bus. Where the PWDATA bus will write the data, is chosen by the PADDR bus value, which currently points to three seperate registers. Much of the code explanation is provided in the code(s), in the form of comments. The following figure shows the elaborated diagram of the APB Controller (I had to take two seperate screenshots, since the original diagram was big).
<figure>
<img width="1591" height="712" alt="controller_elaborate_1" src="https://github.com/user-attachments/assets/75f34d8a-cf2f-46e9-99d7-a7d1975e936b" />
  <br><br>
  <figcaption>
    Elaborated Diagram of APB Port Interface - 1
  </figcaption>
</figure>

<figure>
<img width="713" height="797" alt="controller_elaborate-2" src="https://github.com/user-attachments/assets/3c3f2613-9e6b-4221-b3df-e7f0c6ee17d7" />
  <br><br>
  <figcaption>
    Elaborated Diagram of APB Port Interface - 2
  </figcaption>
</figure>


## Simulation Waveforms

<figure>
  <img width="1573" height="381" alt="port_inf" src="https://github.com/user-attachments/assets/862bbee6-b7b0-46ad-a39e-69af69e72025" />
  <br><br>
  <figcaption>
    Simulation Waveform of GPIO Port Interface
  </figcaption>
</figure>
<br><br><br>
<figure>
  <img width="1556" height="481" alt="cotroller" src="https://github.com/user-attachments/assets/a77a7045-e877-4eee-b731-dcf41bd0f426" />
  <br><br>
  <figcaption>
    Simulation Waveform of APB Controller
  </figcaption>
</figure>

