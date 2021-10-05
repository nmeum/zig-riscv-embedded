package main

import (
	"fmt"
	"log"
	"os"
	"path/filepath"
)

const (
	bufSize  = 1024
	baudRate = 115200
)

var (
	out = os.Stdout
	err = os.Stderr
)

var logger = log.New(err, "", log.Lshortfile)

func main() {
	if len(os.Args) < 3 {
		fmt.Fprintf(os.Stderr, "USAGE: %s ADDR PATH\n", filepath.Base(os.Args[0]))
		os.Exit(1)
	}

	addr := os.Args[1]
	path := os.Args[2]

	cep, err := NewCoapEP(addr)
	if err != nil {
		logger.Fatal(err)
	}
	defer cep.Close()

	sep, err := NewSerialEP(path)
	if err != nil {
		logger.Fatal(err)
	}
	defer sep.Close()

	dispatcher := &Dispatcher{cep, sep}
	dispatcher.Run()
}
