import { calculatePayslip } from '../src/functions/hr';

describe('Payroll Logic Math', () => {
  it('correctly calculates PAYE, NHIF, and NSSF deductions', () => {
    const gross = 100000;
    const settings = {
      payeRate: 30, // 30%
      nhifRate: 2.75, // 2.75%
      nssfRate: 6, // 6%
      housingLevyRate: 1.5 // 1.5%
    };

    const result = calculatePayslip(gross, settings);

    expect(result.paye).toBe(30000);
    expect(result.nhif).toBe(2750);
    expect(result.nssf).toBe(6000);
    expect(result.ahl).toBe(1500);
    
    expect(result.deductions).toBe(40250); // 30000 + 2750 + 6000 + 1500
    expect(result.netPay).toBe(59750); // 100000 - 40250
  });

  it('handles zero base salary gracefully', () => {
    const gross = 0;
    const settings = { payeRate: 30, nhifRate: 2.75, nssfRate: 6 };

    const result = calculatePayslip(gross, settings);

    expect(result.paye).toBe(0);
    expect(result.nhif).toBe(0);
    expect(result.nssf).toBe(0);
    expect(result.deductions).toBe(0);
    expect(result.netPay).toBe(0);
  });
});
