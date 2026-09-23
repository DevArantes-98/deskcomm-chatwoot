import {
  getResponseThermometerStatus,
  levelForMinutes,
  THERMOMETER_DOT_CLASS,
  THERMOMETER_LEVELS,
} from '../responseThermometerHelper';

describe('responseThermometerHelper', () => {
  describe('levelForMinutes', () => {
    it.each([
      [0, 'green'],
      [4.9, 'green'],
      [5, 'yellow'],
      [14.9, 'yellow'],
      [15, 'orange'],
      [44.9, 'orange'],
      [45, 'red'],
      [600, 'red'],
    ])('maps %s minutes to %s', (minutes, level) => {
      expect(levelForMinutes(minutes)).toBe(level);
    });
  });

  describe('getResponseThermometerStatus', () => {
    const now = new Date('2026-09-23T12:00:00Z').getTime();
    const secondsAgo = seconds => Math.floor(now / 1000) - seconds;

    it('returns null when the conversation is not waiting for a reply', () => {
      expect(getResponseThermometerStatus({}, now)).toBeNull();
      expect(
        getResponseThermometerStatus({ waiting_since: 0 }, now)
      ).toBeNull();
    });

    it('reads waiting_since in seconds, in snake_case or camelCase', () => {
      const snake = getResponseThermometerStatus(
        { waiting_since: secondsAgo(10 * 60) },
        now
      );
      const camel = getResponseThermometerStatus(
        { waitingSince: secondsAgo(10 * 60) },
        now
      );

      expect(snake).toEqual({ level: 'yellow', minutes: 10 });
      expect(camel).toEqual(snake);
    });

    it('accepts a millisecond epoch and an ISO string', () => {
      const fromMillis = getResponseThermometerStatus(
        { waitingSince: now - 20 * 60 * 1000 },
        now
      );
      const fromIso = getResponseThermometerStatus(
        { waitingSince: new Date(now - 60 * 60 * 1000).toISOString() },
        now
      );

      expect(fromMillis.level).toBe('orange');
      expect(fromIso.level).toBe('red');
    });

    it('never reports negative waiting time', () => {
      const status = getResponseThermometerStatus(
        { waitingSince: secondsAgo(-300) },
        now
      );

      expect(status).toEqual({ level: 'green', minutes: 0 });
    });
  });

  describe('THERMOMETER_DOT_CLASS', () => {
    it('has a class for every level', () => {
      THERMOMETER_LEVELS.forEach(level => {
        expect(THERMOMETER_DOT_CLASS[level]).toMatch(/^bg-/);
      });
    });
  });
});
