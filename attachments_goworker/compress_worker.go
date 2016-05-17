package main

import (
	"os/exec"
	"io/ioutil"
	"github.com/jrallison/go-workers"
	"log"
	"fmt"
	"bufio"
	"os"
	"github.com/davecgh/go-spew/spew"
)

func CompressWorker(message *workers.Msg) {
	log.Printf("Compress Worker")
	account_id,_ := message.Get("args").Get("account_id").String()
	identity_id,_ := message.Get("args").Get("identity_id").String()
	svc := setupAmazon()
	
	cmdData := "cd " + account_id + ";tar -c " + identity_id + " | gzip > " + identity_id + ".tgz" 

	cmd := exec.Command("sh","-c", cmdData)
	
	cmdReader, err := cmd.StderrPipe()
	if err != nil {
		fmt.Fprintln(os.Stderr, "Error creating StdoutPipe for Cmd", err)
		os.Exit(1)
	}

	scanner := bufio.NewScanner(cmdReader)
	go func() {
		for scanner.Scan() {
			fmt.Printf("%s%% complete\n", scanner.Text())
		}
	}()

	err = cmd.Start()
	if err != nil {
		fmt.Fprintln(os.Stderr, "Error starting Cmd", err)
		os.Exit(1)
	}

	err = cmd.Wait()
	if err != nil {
		fmt.Fprintln(os.Stderr, "Error waiting for Cmd", err)
		os.Exit(1)
	}
	
	data, err := ioutil.ReadFile(account_id + "/" + identity_id + ".tgz")
	if err != nil {
		log.Printf("error reading file from disk: %v", err)
	}
	resp, _ := s3Upload(svc,S3_BUCKET,account_id + "/" + identity_id + ".tgz",data,"")
    spew.Dump(resp) 
    redisClient.LPush(account_id + ":" + identity_id + ":zip:list", "compress")
}