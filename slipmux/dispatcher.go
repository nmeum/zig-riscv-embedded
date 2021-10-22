package main

import (
	"github.com/Lobaro/slip"
	"os"
)

type Dispatcher struct {
	coap   *CoapEndpoint
	serial *SerialEndpoint
}

func (d *Dispatcher) handleCoap(data []byte) {
	// TODO: Create this writer once.
	w := slip.NewSlipMuxWriter(NewSlowWriter(d.serial.port))

	err := w.WritePacket(slip.FRAME_COAP, data)
	if err != nil {
		logger.Println("handleCoap:", err)
		return
	}
}

func (d *Dispatcher) handleSerial(data []byte) {
	if len(data) <= 2 {
		return
	}

	frame := data[0]
	switch frame {
	case slip.FRAME_DIAGNOSTIC:
		msg := data[1:len(data)]

		_, err := os.Stdout.WriteString(string(msg))
		if err != nil {
			logger.Println("handleSerial:", err)
		}
	default:
		logger.Printf("handleSerial: Unsupported frame type: 0x%x\n", frame)
	}
}

func (d *Dispatcher) Run() {
	for {
		select {
		case data := <-d.coap.RX:
			d.handleCoap(data)
		case data := <-d.serial.Chan:
			d.handleSerial(data)
		}
	}
}
