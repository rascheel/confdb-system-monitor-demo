package main

import (
	"bytes"
	"encoding/json"
	"fmt"
	"log"
	"os/exec"
	"strconv"
	"strings"
	"sync"
	"time"
)


// debugLog is a helper to keep the main logic cleaner
var EnableDebug = true
func debugLog(format string, v ...interface{}) {
	if EnableDebug {
		log.Printf("[DEBUG] " + format, v...)
	}
}

type Severity int

const (
	Info Severity = iota
	Warning
	Critical
)

type CompOperator string

const (
	GT  CompOperator = ">"
	LT  CompOperator = "<"
	EQ  CompOperator = "=="
	GTE CompOperator = ">="
	LTE CompOperator = "<="
	NEQ CompOperator = "!="
)

type FaultConfig struct {
	Name                string       `json:"name"`
	Severity            Severity     `json:"severity"`
	ConfdbHookPoll      string       `json:"confdb-hook-poll"`
	TriggerThreshold    int          `json:"trigger-threshold"`
	TriggerThresholdCnt int          `json:"trigger-threshold-cnt"`
	TriggerComp         CompOperator `json:"trigger-comp"`
	HysteresisThreshold int          `json:"hysteresis-threshold"`
	PollRateMs          int          `json:"poll-rate-ms"`
}

func snapctlGetConfdb(view string, key string) (string, error) {
	// Notice that 'key' is now appended to the argument list
	cmd := exec.Command("snapctl", "get", "--view", view, key)
	
	var stdout bytes.Buffer
	var stderr bytes.Buffer
	
	// Bind both standard out and standard error
	cmd.Stdout = &stdout
	cmd.Stderr = &stderr
	
	
	//log.Printf("Executing command error'd: %s\n", cmd.String())
	err := cmd.Run()
	if err != nil {
		// Log the Go error, plus whatever snapctl actually complained about in stderr
		log.Printf("Executing command error'd: %s\n", cmd.String())
		log.Printf("Command failed with error: %v\n", err)
		log.Printf("snapctl stderr: %s\n", strings.TrimSpace(stderr.String()))
		log.Printf("snapctl stdout (if any): %s\n", strings.TrimSpace(stdout.String()))
		
		// Return a wrapped error so the caller also gets the stderr context
		return "", fmt.Errorf("snapctl failed: %w (stderr: %s)", err, strings.TrimSpace(stderr.String()))
	}
	
	output := strings.TrimSpace(stdout.String())
	//log.Printf("Command succeeded. Output length: %d bytes\n", len(output))
	
	return output, nil
}

// snapctlGet reads standard snap config values (used for polling the dynamic hooks)
func snapctlGet(key string) (string, error) {
	cmd := exec.Command("snapctl", "get", key)
	var out bytes.Buffer
	cmd.Stdout = &out
	err := cmd.Run()
	if err != nil {
		return "", err
	}
	return strings.TrimSpace(out.String()), nil
}

// checkThreshold safely evaluates the comparison between the polled value and the threshold
func checkThreshold(val, threshold int, op CompOperator) bool {
	switch op {
	case GT:  return val > threshold
	case LT:  return val < threshold
	case EQ:  return val == threshold
	case GTE: return val >= threshold
	case LTE: return val <= threshold
	case NEQ: return val != threshold
	default:  return false
	}
}

// getHysteresisOp inverts the trigger operator so we know how to evaluate the clearing threshold
func getHysteresisOp(op CompOperator) CompOperator {
	switch op {
	case GT:  return LTE
	case LT:  return GTE
	case GTE: return LT
	case LTE: return GT
	case EQ:  return NEQ
	case NEQ: return EQ
	default:  return op
	}
}

// getSeverityStr maps the enum to a human-readable string for logging
func getSeverityStr(s Severity) string {
	switch s {
	case Info:     return "INFO"
	case Warning:  return "WARNING"
	case Critical: return "CRITICAL"
	default:       return "UNKNOWN"
	}
}

func monitorFault(config FaultConfig, wg *sync.WaitGroup) {
	defer wg.Done()

	ticker := time.NewTicker(time.Duration(config.PollRateMs) * time.Millisecond)
	defer ticker.Stop()

	log.Printf("Starting monitor for %s (Polling '%s' every %dms)\n", config.Name, config.ConfdbHookPoll, config.PollRateMs)

	isFaulted := false
	triggerCount := 0

	for range ticker.C {
		valStr, err := snapctlGetConfdb(":cpu-stats", config.ConfdbHookPoll)
		if err != nil || valStr == "" {
			debugLog("[%s] No value or error reading from confdb", config.Name)
			continue
		}

		// Parse strictly as an integer
		polledVal, err := strconv.Atoi(valStr)
		if err != nil {
			log.Printf("[%s] Error parsing polled value '%s' as int: %v\n", config.Name, valStr, err)
			continue
		}

		// Trace the incoming value before evaluation
		debugLog("[%s] Polled: %d | State: Faulted=%t | Count: %d/%d", 
			config.Name, polledVal, isFaulted, triggerCount, config.TriggerThresholdCnt)

		if !isFaulted {
			// 1. Evaluate if the value violates the trigger threshold
			if checkThreshold(polledVal, config.TriggerThreshold, config.TriggerComp) {
				triggerCount++
				
				debugLog("[%s] Condition met (%d %s %d). Incrementing count to %d", 
					config.Name, polledVal, config.TriggerComp, config.TriggerThreshold, triggerCount)
				
				// 2. Check if we have hit the required consecutive trigger count
				if triggerCount >= config.TriggerThresholdCnt {
					isFaulted = true
					log.Printf("[%s] FAULT TRIGGERED! [Severity: %s] Value %d met condition '%s %d' (%d consecutive polls)\n",
						config.Name, getSeverityStr(config.Severity), polledVal, config.TriggerComp, config.TriggerThreshold, config.TriggerThresholdCnt)
				}
			} else {
				// Reset count if the value falls back into normal bounds before triggering the fault
				if triggerCount > 0 {
					debugLog("[%s] Value returned to normal before trigger threshold met. Resetting count to 0.", config.Name)
					triggerCount = 0
				}
			}
		} else {
			// 3. Fault is active; evaluate the hysteresis threshold to see if we can clear it
			clearOp := getHysteresisOp(config.TriggerComp)
			
			debugLog("[%s] Evaluating clear condition (%d %s %d)", 
				config.Name, polledVal, clearOp, config.HysteresisThreshold)
				
			if checkThreshold(polledVal, config.HysteresisThreshold, clearOp) {
				isFaulted = false
				triggerCount = 0 // Reset the count for the next potential fault
				
				log.Printf("[%s] FAULT CLEARED! Value %d returned to normal bounds (Condition: '%s %d')\n",
					config.Name, polledVal, clearOp, config.HysteresisThreshold)
			}
		}
	}
}

func main() {
	log.Println("Starting fault-monitor daemon...")

	var faultsJSON string
	var err error

	// Loop indefinitely until we get a successful read
	for {
		faultsJSON, err = snapctlGetConfdb(":faults-manager", "faults")
		if err != nil {
			log.Printf("Failed to read 'faults' config (likely locked): %v\n", err)
			log.Println("Retrying in 5 seconds...")
			time.Sleep(5 * time.Second)
			continue
		}
		
		// If we succeed, break out of the retry loop
		break
	}

	// Handle the case where the read succeeds, but the configuration is empty
	if faultsJSON == "" || faultsJSON == "null" || faultsJSON == "[]" {
		log.Println("No faults configured. Please set faults via the confdb interface.")
		// We block here so the daemon doesn't crashloop
		select {} 
	}

	var configs []FaultConfig
	err = json.Unmarshal([]byte(faultsJSON), &configs)
	if err != nil {
		log.Fatalf("Failed to parse 'faults' JSON: %v\nJSON was: %s\n", err, faultsJSON)
	}

	log.Printf("Loaded %d fault configurations.\n", len(configs))

	var wg sync.WaitGroup
	for _, cfg := range configs {
		if cfg.PollRateMs <= 0 {
			log.Printf("Skipping %s: invalid poll rate (%dms)\n", cfg.Name, cfg.PollRateMs)
			continue
		}
		wg.Add(1)
		go monitorFault(cfg, &wg)
	}

	wg.Wait()
	log.Println("All monitors stopped. Exiting.")
}
