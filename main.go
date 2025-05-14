package main

import (
	"context"
	"flag"
	"fmt"
	"os"
	"os/exec"
	"strings"

	secretmanager "cloud.google.com/go/secretmanager/apiv1"
	"cloud.google.com/go/secretmanager/apiv1/secretmanagerpb"
)

func main() {
	// Parse command line arguments
	secretName := flag.String("name", "", "Name of the secret to retrieve")
	flag.Parse()

	if *secretName == "" {
		fmt.Println("Error: Secret name is required")
		fmt.Println("Usage: gsm --name=SECRET_NAME")
		os.Exit(1)
	}

	// Get current GCP project using gcloud
	cmd := exec.Command("gcloud", "config", "get-value", "project")
	output, err := cmd.Output()
	if err != nil {
		fmt.Printf("Failed to get current GCP project: %v\n", err)
		os.Exit(1)
	}
	projectID := strings.TrimSpace(string(output))

	if projectID == "" {
		fmt.Println("Error: No GCP project configured")
		os.Exit(1)
	}

	// Create the client
	ctx := context.Background()
	client, err := secretmanager.NewClient(ctx)
	if err != nil {
		fmt.Printf("Failed to create secretmanager client: %v\n", err)
		os.Exit(1)
	}
	defer client.Close()

	// Build the resource name of the secret version
	name := fmt.Sprintf("projects/%s/secrets/%s/versions/latest", projectID, *secretName)

	// Access the secret version
	req := &secretmanagerpb.AccessSecretVersionRequest{
		Name: name,
	}
	result, err := client.AccessSecretVersion(ctx, req)
	if err != nil {
		fmt.Printf("Failed to access secret version: %v\n", err)
		os.Exit(1)
	}

	// Print the secret payload
	fmt.Printf("%s\n", result.Payload.Data)
}

