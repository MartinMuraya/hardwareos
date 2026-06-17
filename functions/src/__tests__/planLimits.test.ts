import { PLAN_LIMITS, GRACE_PERIOD_DAYS, TRIAL_DAYS } from "../config/planLimits";

describe("PlanLimits", () => {
  describe("PLAN_LIMITS", () => {
    it("defines limits for free plan", () => {
      const free = PLAN_LIMITS["free"];
      expect(free).toBeDefined();
      expect(free.maxProducts).toBe(50);
      expect(free.maxUsers).toBe(1);
    });

    it("defines limits for starter plan", () => {
      const starter = PLAN_LIMITS["starter"];
      expect(starter).toBeDefined();
      expect(starter.maxProducts).toBe(500);
      expect(starter.maxUsers).toBe(5);
    });

    it("defines limits for pro plan", () => {
      const pro = PLAN_LIMITS["pro"];
      expect(pro).toBeDefined();
      expect(pro.maxProducts).toBe(-1);
      expect(pro.maxUsers).toBe(-1);
    });
  });

  describe("Constants", () => {
    it("has a 3-day grace period", () => {
      expect(GRACE_PERIOD_DAYS).toBe(3);
    });

    it("has a 14-day trial", () => {
      expect(TRIAL_DAYS).toBe(14);
    });
  });
});
