package main

import (
	"fmt"
	"log"
	"net"
	"os"
	"path/filepath"

	"github.com/Lobaro/slip"
	"github.com/plgd-dev/go-coap/v2/message"
	coap "github.com/plgd-dev/go-coap/v2/udp/message"
)

const (
	bufSize = 1024
	maxOpts = 32
)

var (
	out = os.Stdout
	err = os.Stderr
)

var logger = log.New(err, "coap-slip", log.Lshortfile)

func handleData(data []byte, w *slip.SlipMuxWriter) {
	var msg coap.Message
	msg.Options = make(message.Options, 0, maxOpts)

	_, err := msg.Unmarshal(data)
	if err != nil {
		logger.Println("Unmarshal:", err)
		return
	}

	serialized, err := msg.Marshal()
	if err != nil {
		logger.Println("Marshal:", err)
		return
	}

	err = w.WritePacket(slip.FRAME_COAP, serialized)
	if err != nil {
		logger.Println("WritePacket:", err)
		return
	}
}

func main() {
	if len(os.Args) < 2 {
		fmt.Fprintf(os.Stderr, "USAGE: %s ADDR\n", filepath.Base(os.Args[0]))
		os.Exit(1)
	}
	addr := os.Args[1]

	ln, err := net.ListenPacket("udp", addr)
	if err != nil {
		logger.Fatal(err)
	}
	defer ln.Close()

	buf := make([]byte, bufSize)
	writer := slip.NewSlipMuxWriter(out)

	for {
		n, _, err := ln.ReadFrom(buf)
		if err != nil {
			logger.Println("ReadFrom:", err)
			continue
		}

		handleData(buf[0:n], writer)
	}
}
