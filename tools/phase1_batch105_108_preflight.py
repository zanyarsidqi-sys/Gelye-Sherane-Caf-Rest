#!/usr/bin/env python3
"""Offline regression assertions; NOT Dart compilation or printer hardware test."""
from pathlib import Path
import unittest
class PrintIntegrationChecks(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.root=Path(__file__).resolve().parents[1]
        cls.source=(cls.root/'lib/services/station_print_worker.dart').read_text()
    def test_project_specific_brand(self):
        self.assertIn("'GELYE SHERANE CAFE & REST'",self.source)
        self.assertNotIn("'GELYE SHERANE CAFE & RESTAURANT'",self.source)
    def test_shutdown_before_print(self):
        self.assertLess(self.source.index('if (_stopped) {',self.source.index('final identity =')),self.source.index('await printer.print(output)'))
    def test_order_identity(self):
        self.assertIn("ticket.orderId != claim['order_id']",self.source)
    def test_queue_name(self):
        self.assertIn("queueName.trim().isEmpty",self.source)
    def test_positive_poll_interval(self):
        self.assertIn('interval <= Duration.zero',self.source)
    def test_existing_ack_path(self):
        self.assertIn('acknowledgePrintTicket',self.source)
        self.assertIn('StationPrintOutcome.uncertain',self.source)
if __name__=='__main__': unittest.main(verbosity=2)
