#!/usr/bin/env python3
"""
MobSF (Mobile Security Framework) Scanner for Talk To Me Flutter Apps
Scans Android APKs for security vulnerabilities using MobSF API

Usage:
    python3 mobsf_scan.py --apk path/to/app.apk --api-key YOUR_API_KEY [--fail-on critical,high]

Environment Variables:
    MOBSF_API_KEY: MobSF API key (required)
    MOBSF_URL: MobSF server URL (default: https://mobsf.example.com/api/v1)
    MOBSF_TIMEOUT: Request timeout in seconds (default: 60)
    MOBSF_POLL_INTERVAL: Poll interval in seconds (default: 10)
    MOBSF_MAX_POLLS: Maximum number of poll attempts (default: 60)

Exit Codes:
    0: Success - no vulnerabilities above threshold
    1: Failure - vulnerabilities found above threshold or error
    2: Configuration error
    3: Network/API error
"""

import argparse
import os
import sys
import time
import json
import requests
from pathlib import Path
from typing import Dict, List, Optional, Tuple


class MobSFScanner:
    """MobSF API client for scanning Android APKs"""
    
    def __init__(
        self,
        api_key: str,
        base_url: str = "https://mobsf.example.com/api/v1",
        timeout: int = 60,
        poll_interval: int = 10,
        max_polls: int = 60
    ):
        self.api_key = api_key
        self.base_url = base_url.rstrip('/')
        self.timeout = timeout
        self.poll_interval = poll_interval
        self.max_polls = max_polls
        self.session = requests.Session()
        self.session.headers.update({'Authorization': api_key})
    
    def upload_apk(self, apk_path: Path) -> str:
        """Upload APK to MobSF and return file hash"""
        if not apk_path.exists():
            raise FileNotFoundError(f"APK not found: {apk_path}")
        
        print(f"Uploading {apk_path.name}...")
        with open(apk_path, 'rb') as f:
            files = {'file': (apk_path.name, f, 'application/vnd.android.package-archive')}
            resp = self.session.post(
                f'{self.base_url}/upload',
                files=files,
                timeout=self.timeout
            )
        
        if resp.status_code != 200:
            raise RuntimeError(f"Upload failed ({resp.status_code}): {resp.text}")
        
        result = resp.json()
        file_hash = result.get('hash')
        if not file_hash:
            raise RuntimeError(f"No hash returned: {result}")
        
        print(f"Uploaded successfully. Hash: {file_hash}")
        return file_hash
    
    def start_scan(self, file_hash: str, scan_type: str = 'apk') -> None:
        """Start static analysis scan"""
        print("Starting static analysis scan...")
        resp = self.session.post(
            f'{self.base_url}/scan',
            data={'hash': file_hash, 'scan_type': scan_type},
            timeout=self.timeout
        )
        
        if resp.status_code != 200:
            raise RuntimeError(f"Scan start failed ({resp.status_code}): {resp.text}")
        
        print("Scan started successfully")
    
    def wait_for_scan(self, file_hash: str) -> Dict:
        """Poll for scan completion and return report"""
        print("Waiting for scan to complete...")
        
        for attempt in range(self.max_polls):
            resp = self.session.post(
                f'{self.base_url}/report_json',
                data={'hash': file_hash},
                timeout=self.timeout
            )
            
            if resp.status_code == 200:
                report = resp.json()
                # Check if scan is complete (has vulnerabilities or completed flag)
                if 'vulnerabilities' in report or report.get('scan_status') == 'completed':
                    print("Scan completed successfully")
                    return report
            
            elif resp.status_code == 404:
                # Scan might still be in progress
                pass
            
            else:
                print(f"Poll {attempt + 1}: Status {resp.status_code}")
            
            if attempt < self.max_polls - 1:
                print(f"Waiting... (attempt {attempt + 1}/{self.max_polls})")
                time.sleep(self.poll_interval)
        
        raise TimeoutError(f"Scan did not complete within {self.max_polls * self.poll_interval} seconds")
    
    def get_report(self, file_hash: str) -> Dict:
        """Get full JSON report"""
        resp = self.session.post(
            f'{self.base_url}/report_json',
            data={'hash': file_hash},
            timeout=self.timeout
        )
        
        if resp.status_code != 200:
            raise RuntimeError(f"Report failed ({resp.status_code}): {resp.text}")
        
        return resp.json()
    
    def scan_apk(self, apk_path: Path) -> Dict:
        """Complete scan workflow: upload, scan, wait, return report"""
        file_hash = self.upload_apk(apk_path)
        self.start_scan(file_hash)
        return self.wait_for_scan(file_hash)
    
    def filter_vulnerabilities(
        self,
        report: Dict,
        fail_on: List[str]
    ) -> List[Dict]:
        """Filter vulnerabilities by severity"""
        severity_order = {'critical': 4, 'high': 3, 'medium': 2, 'low': 1, 'info': 0}
        fail_levels = {s.lower() for s in fail_on}
        min_severity = min((severity_order.get(s, 0) for s in fail_levels), default=0)
        
        vulnerabilities = report.get('vulnerabilities', [])
        filtered = []
        
        for vuln in vulnerabilities:
            severity = vuln.get('severity', '').lower()
            if severity in severity_order and severity_order[severity] >= min_severity:
                filtered.append(vuln)
        
        return filtered
    
    def print_vulnerabilities(self, vulns: List[Dict], app_name: str) -> None:
        """Print vulnerabilities in a formatted way"""
        if not vulns:
            print(f"\n✅ No vulnerabilities above threshold found in {app_name}")
            return
        
        print(f"\n❌ {len(vulns)} vulnerabilities found in {app_name}:")
        print("-" * 80)
        
        for i, vuln in enumerate(vulns, 1):
            severity = vuln.get('severity', 'unknown').upper()
            title = vuln.get('title', 'Unknown')
            cwe = vuln.get('cwe', 'N/A')
            cvss = vuln.get('cvss', 'N/A')
            file_path = vuln.get('file_path', 'N/A')
            line = vuln.get('line', 'N/A')
            
            print(f"  {i}. [{severity}] {title}")
            print(f"     CWE: {cwe} | CVSS: {cvss} | File: {file_path}:{line}")
            
            description = vuln.get('description', '')
            if description:
                # Truncate long descriptions
                desc = description[:200] + "..." if len(description) > 200 else description
                print(f"     Description: {desc}")
            print()


def main():
    parser = argparse.ArgumentParser(
        description="MobSF Scanner for Talk To Me Flutter Apps",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  python3 mobsf_scan.py --apk app.apk --api-key $MOBSF_API_KEY
  python3 mobsf_scan.py --apk app.apk --api-key $MOBSF_API_KEY --fail-on critical,high
  python3 mobsf_scan.py --apk app.apk --api-key $MOBSF_API_KEY --url https://mobsf.internal/api/v1 --fail-on critical
        """
    )
    
    parser.add_argument(
        '--apk',
        type=Path,
        required=True,
        help='Path to APK file to scan'
    )
    
    parser.add_argument(
        '--api-key',
        required=False,
        help='MobSF API key (or set MOBSF_API_KEY env var)'
    )
    
    parser.add_argument(
        '--url',
        default=os.getenv('MOBSF_URL', 'https://mobsf.example.com/api/v1'),
        help='MobSF server URL (default: https://mobsf.example.com/api/v1)'
    )
    
    parser.add_argument(
        '--fail-on',
        default='critical,high',
        help='Comma-separated severities to fail on (default: critical,high)'
    )
    
    parser.add_argument(
        '--timeout',
        type=int,
        default=60,
        help='Request timeout in seconds (default: 60)'
    )
    
    parser.add_argument(
        '--poll-interval',
        type=int,
        default=10,
        help='Poll interval in seconds (default: 10)'
    )
    
    parser.add_argument(
        '--max-polls',
        type=int,
        default=60,
        help='Maximum poll attempts (default: 60)'
    )
    
    parser.add_argument(
        '--output-json',
        type=Path,
        help='Write full report to JSON file'
    )
    
    parser.add_argument(
        '--skip-upload',
        action='store_true',
        help='Skip upload (use existing hash from --hash)'
    )
    
    parser.add_argument(
        '--hash',
        help='Existing file hash to scan (skips upload)'
    )
    
    args = parser.parse_args()
    
    # Get API key
    api_key = args.api_key or os.getenv('MOBSF_API_KEY')
    if not api_key:
        print("Error: API key required. Use --api-key or set MOBSF_API_KEY environment variable.", file=sys.stderr)
        sys.exit(2)
    
    # Parse fail-on severities
    fail_on = [s.strip().lower() for s in args.fail_on.split(',')]
    valid_severities = {'critical', 'high', 'medium', 'low', 'info'}
    invalid = [s for s in fail_on if s not in valid_severities]
    if invalid:
        print(f"Error: Invalid severity levels: {invalid}. Valid: {valid_severities}", file=sys.stderr)
        sys.exit(2)
    
    # Validate APK exists
    if not args.skip_upload and not args.apk.exists():
        print(f"Error: APK not found: {args.apk}", file=sys.stderr)
        sys.exit(1)
    
    try:
        scanner = MobSFScanner(
            api_key=api_key,
            base_url=args.url,
            timeout=args.timeout,
            poll_interval=args.poll_interval,
            max_polls=args.max_polls
        )
        
        # Scan APK
        if args.skip_upload and args.hash:
            print(f"Using existing hash: {args.hash}")
            scanner.start_scan(args.hash)
            report = scanner.wait_for_scan(args.hash)
        else:
            report = scanner.scan_apk(args.apk)
        
        # Save full report if requested
        if args.output_json:
            with open(args.output_json, 'w') as f:
                json.dump(report, f, indent=2)
            print(f"Full report saved to: {args.output_json}")
        
        # Filter vulnerabilities
        fail_on_vulns = scanner.filter_vulnerabilities(report, fail_on)
        
        # Print results
        app_name = args.apk.stem if not args.skip_upload else args.hash[:8]
        scanner.print_vulnerabilities(fail_on_vulns, app_name)
        
        # Exit with appropriate code
        if fail_on_vulns:
            print(f"\n🛑 BUILD FAILED: {len(fail_on_vulns)} vulnerabilities at or above {', '.join(fail_on).upper()} severity")
            sys.exit(1)
        else:
            print(f"\n✅ BUILD PASSED: No vulnerabilities at or above {', '.join(fail_on).upper()} severity")
            sys.exit(0)
            
    except FileNotFoundError as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)
    except requests.exceptions.ConnectionError as e:
        print(f"Error: Cannot connect to MobSF at {args.url}: {e}", file=sys.stderr)
        sys.exit(3)
    except requests.exceptions.Timeout as e:
        print(f"Error: Request timeout: {e}", file=sys.stderr)
        sys.exit(3)
    except requests.exceptions.RequestException as e:
        print(f"Error: API request failed: {e}", file=sys.stderr)
        sys.exit(3)
    except TimeoutError as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(3)
    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)


if __name__ == '__main__':
    main()