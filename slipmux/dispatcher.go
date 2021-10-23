package main

import (
	"os"

	"github.com/Lobaro/slip"
)

type Dispatcher struct {
	coap   *CoapEndpoint
	serial *SerialEndpoint
}

func (d *Dispatcher) handleCoap(data []byte) {
	d.serial.TX <- data
}

func (d *Dispatcher) handleSerial(pkt Packet) {
	switch pkt.FrameType {
	case slip.FRAME_DIAGNOSTIC:
		_, err := os.Stdout.WriteString(string(pkt.Data))
		if err != nil {
			logger.Println("handleSerial:", err)
		}
	case slip.FRAME_COAP:
		d.coap.TX <- pkt.Data
	default:
		logger.Printf("handleSerial: Unsupported frame type: 0x%x\n", pkt.FrameType)
	}
}

func (d *Dispatcher) Run() {
	for {
		select {
		case data := <-d.coap.RX:
			d.handleCoap(data)
		case pkt := <-d.serial.RX:
			d.handleSerial(pkt)
		}
	}
}
