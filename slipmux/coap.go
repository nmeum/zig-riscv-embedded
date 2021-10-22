package main

import (
	"net"
)

type CoapEndpoint struct {
	conn     net.PacketConn
	lastAddr *net.Addr
	// XXX: mutex?

	RX <-chan []byte
	TX chan<- []byte
}

func NewCoapEP(addr string) (*CoapEndpoint, error) {
	conn, err := net.ListenPacket("udp", addr)
	if err != nil {
		return nil, err
	}

	rx := make(chan []byte)
	tx := make(chan []byte)

	ep := &CoapEndpoint{
		conn:     conn,
		lastAddr: nil,
		RX:       rx,
		TX:       tx,
	}

	go ep.sndLoop(tx)
	go ep.rcvLoop(rx)

	return ep, nil
}

func (c *CoapEndpoint) sndLoop(ch <-chan []byte) {
	for {
		data := <-ch

		if c.lastAddr == nil {
			logger.Println("[CoapEndpoint] Unexpected CoAP send")
			continue
		}

		_, err := c.conn.WriteTo(data, *c.lastAddr)
		if err != nil {
			logger.Println("[CoapEndpoint] WriteTo failed", err)
			continue
		}
	}
}

func (c *CoapEndpoint) rcvLoop(ch chan<- []byte) {
	buf := make([]byte, bufSize)

	for {
		n, addr, err := c.conn.ReadFrom(buf)
		if err != nil {
			logger.Println("[CoapEndpoint] ReadFrom failed", err)
			continue
		}

		c.lastAddr = &addr
		ch <- buf[0:n]
	}
}

func (c *CoapEndpoint) Close() {
	// close(c.Chan)
	c.conn.Close()
}
