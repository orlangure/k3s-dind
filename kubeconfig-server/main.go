package main

import (
	"flag"
	"fmt"
	"log"
	"net/http"
)

func main() {
	log.Println("starting config server...")
	var (
		dir  string
		port int
	)

	flag.StringVar(&dir, "dir", "/config", "root directory to serve")
	flag.IntVar(&port, "port", 80, "port number to listen on")
	flag.Parse()

	http.Handle("/", http.FileServer(http.Dir(dir)))
	http.ListenAndServe(fmt.Sprintf(":%d", port), nil)
}
