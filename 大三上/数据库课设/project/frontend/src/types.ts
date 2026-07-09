export interface Session {
  day: number;       // 1-7
  day_str: string;
  start: number;     // 1-11
  end: number;
  weeks: string;
  location: string;
  teacher: string;
}

export interface Course {
  id: string;
  name: string;
  teacher_display: string;
  raw_schedule: string;
  sessions: Session[];
}